#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"

root = File.expand_path("..", __dir__)
native_image_dir = File.join(
  root,
  "src/main/resources/META-INF/native-image/com.example/truffle-gui-native"
)
classpath_file = File.join(root, "target/classpath.txt")

Dir.chdir(root) do
  system(
    "mvn",
    "-q",
    "compile",
    "dependency:build-classpath",
    "-Dmdep.outputFile=target/classpath.txt",
    exception: true
  )
end

classpath = File.read(classpath_file).split(File::PATH_SEPARATOR)
classpath_arg = classpath.join(File::PATH_SEPARATOR)
jni_config_file = File.join(native_image_dir, "jni-config.json")
swt_jars = classpath.select do |path|
  File.basename(path).start_with?("org.eclipse.swt") && File.file?(path)
end

abort "Could not find SWT jars on the Maven classpath" if swt_jars.empty?

classes = swt_jars.flat_map do |jar_path|
  entries, status = Open3.capture2("jar", "tf", jar_path)
  raise "jar tf failed for #{jar_path}" unless status.success?

  entries.lines.filter_map do |entry|
    entry = entry.chomp
    next unless entry.start_with?("org/eclipse/swt/")
    next unless entry.end_with?(".class")
    next if entry.end_with?("module-info.class", "package-info.class")

    entry.delete_suffix(".class").tr("/", ".")
  end
end.uniq.sort

def java_definitions(class_names, classpath)
  output, status = Open3.capture2("javap", "-classpath", classpath, "-private", *class_names)
  raise "javap failed for SWT classes" unless status.success?

  definitions = {}
  current_class = nil

  output.each_line do |line|
    if (match = line.match(/\b(class|interface)\s+(org\.eclipse\.swt[\w.$]*)\b/))
      current_class = match[2]
      definitions[current_class] = { kind: match[1], lines: [] }
    elsif current_class
      definitions[current_class][:lines] << line
    end
  end

  definitions
end

def callback_methods(definition)
  definition.fetch(:lines).filter_map do |line|
    match = line.strip.match(/\A(?:public |protected |private )?(?:static )?\S+ (\w+Proc)\(([^)]*)\);\z/)
    next unless match

    parameter_types = match[2].split(",").map(&:strip).reject(&:empty?)
    {
      "name" => match[1],
      "parameterTypes" => parameter_types
    }
  end.uniq
end

def cocoa_struct_fields(class_name, definition)
  return [] unless class_name.start_with?("org.eclipse.swt.internal.cocoa.")

  lines = definition.fetch(:lines)
  return [] unless lines.any? { |line| line.strip == "public static final int sizeof;" }

  lines.filter_map do |line|
    match = line.strip.match(/\Apublic (?!static\b)\S+ (\w+);\z/)
    next unless match

    { "name" => match[1] }
  end.uniq
end

definitions = java_definitions(classes, classpath_arg)

host_reflection = [
  {
    "name" => "java.lang.Thread",
    "allPublicConstructors" => true,
    "allPublicMethods" => true
  }
]

swt_reflection = classes.map do |class_name|
  {
    "name" => class_name,
    "allPublicConstructors" => true,
    "allPublicMethods" => true,
    "allPublicFields" => true,
    "queryAllDeclaredConstructors" => true,
    "queryAllDeclaredMethods" => true
  }
end

reflection = host_reflection + swt_reflection

listener_proxies = classes
  .select { |class_name| class_name.end_with?("Listener") && definitions.dig(class_name, :kind) == "interface" }
  .map { |class_name| [class_name] }

proxies = ([["java.lang.Runnable"], ["org.eclipse.swt.widgets.Listener"]] + listener_proxies).uniq

callback_jni = classes.filter_map do |class_name|
  definition = definitions[class_name]
  next unless definition

  methods = callback_methods(definition)
  next if methods.empty?

  {
    "name" => class_name,
    "methods" => methods
  }
end

cocoa_struct_jni = classes.filter_map do |class_name|
  definition = definitions[class_name]
  next unless definition

  fields = cocoa_struct_fields(class_name, definition)
  next if fields.empty?

  {
    "name" => class_name,
    "fields" => fields
  }
end
cocoa_struct_names = cocoa_struct_jni.map { |entry| entry["name"] }

jni_config = JSON.parse(File.read(jni_config_file))
jni_config.reject! do |entry|
  (
    entry["name"].start_with?("org.eclipse.swt.") &&
      entry.fetch("methods", []).any? &&
      entry["methods"].all? { |method| method["name"].end_with?("Proc") }
  ) || cocoa_struct_names.include?(entry["name"])
end
jni_config += cocoa_struct_jni + callback_jni

File.write(
  File.join(native_image_dir, "reflect-config.json"),
  "#{JSON.pretty_generate(reflection)}\n"
)
File.write(
  File.join(native_image_dir, "proxy-config.json"),
  "#{JSON.pretty_generate(proxies)}\n"
)
File.write(
  jni_config_file,
  "#{JSON.pretty_generate(jni_config)}\n"
)

puts "Wrote #{host_reflection.length} host reflection entries"
puts "Wrote #{swt_reflection.length} SWT reflection entries"
puts "Wrote #{proxies.length} proxy entries"
puts "Wrote #{cocoa_struct_jni.length} Cocoa struct JNI entries"
puts "Wrote #{callback_jni.length} SWT callback JNI entries"
