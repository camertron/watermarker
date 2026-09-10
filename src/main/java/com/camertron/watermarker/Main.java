package com.camertron.watermarker;

import java.io.IOException;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.Instant;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;

import org.graalvm.polyglot.Context;
import org.graalvm.polyglot.EnvironmentAccess;
import org.graalvm.polyglot.HostAccess;
import org.graalvm.polyglot.PolyglotAccess;
import org.graalvm.polyglot.Source;
import org.graalvm.polyglot.io.IOAccess;

public final class Main {
    private Main() {
    }

    public static void main(String[] args) {
        LaunchLog launchLog = new LaunchLog();
        Thread.setDefaultUncaughtExceptionHandler((thread, throwable) ->
            report(launchLog, "uncaught thread=" + thread.getName() + "\n" + stackTrace(throwable))
        );

        try {
            run(args, launchLog);
            launchLog.write("exit ok");
        } catch (Throwable throwable) {
            report(launchLog, "fatal\n" + stackTrace(throwable));
            System.exit(1);
        }
    }

    private static void run(String[] args, LaunchLog launchLog) throws IOException {
        Path projectRoot = findProjectRoot();
        RubyScript script = loadScript(args, projectRoot);
        Map<String, String> rubyEnvironment = rubyEnvironment();

        launchLog.write(
            "start cwd=" + Path.of("").toAbsolutePath().normalize()
                + " projectRoot=" + projectRoot
                + " script=" + script.name()
                + " args=" + Arrays.toString(args)
        );

        try (Context context = Context.newBuilder("ruby")
            .allowCreateThread(true)
            .allowEnvironmentAccess(EnvironmentAccess.INHERIT)
            .environment(rubyEnvironment)
            .allowExperimentalOptions(true)
            .allowHostAccess(HostAccess.ALL)
            .allowHostClassLookup(Main::isAllowedHostClass)
            .allowHostClassLoading(true)
            .allowIO(IOAccess.ALL)
            .allowNativeAccess(true)
            .allowPolyglotAccess(PolyglotAccess.ALL)
            .option("engine.WarnInterpreterOnly", "false")
            .option("ruby.embedded", "false")
            .build()) {
            context.getPolyglotBindings().putMember("projectRoot", projectRoot.toString());
            context.getPolyglotBindings().putMember(
                "smokeExitMs",
                System.getenv().getOrDefault("WATERMARKER_SMOKE_EXIT_MS", "")
            );

            Source source = Source.newBuilder("ruby", script.contents(), script.name()).build();
            context.eval(source);
        }
    }

    private static boolean isAllowedHostClass(String className) {
        return className.startsWith("java.")
            || className.startsWith("javax.")
            || className.startsWith("org.eclipse.swt.");
    }

    private static Path findProjectRoot() {
        Path workingDirectory = Path.of("").toAbsolutePath().normalize();
        Path executableDirectory = ProcessHandle.current()
            .info()
            .command()
            .map(Path::of)
            .map(Path::toAbsolutePath)
            .map(Path::normalize)
            .map(Path::getParent)
            .orElse(null);

        Path[] candidates = {
            executableDirectory,
            executableDirectory == null ? null : executableDirectory.resolve("../Resources").normalize(),
            workingDirectory
        };

        for (Path candidate : candidates) {
            if (candidate != null && Files.isRegularFile(candidate.resolve("Gemfile"))) {
                return candidate;
            }
        }

        return workingDirectory;
    }

    private static Map<String, String> rubyEnvironment() {
        Map<String, String> environment = new HashMap<>();
        putDefault(environment, "LANG", "en_US.UTF-8");
        putDefault(environment, "LC_ALL", "en_US.UTF-8");

        return environment;
    }

    private static void putDefault(Map<String, String> environment, String name, String value) {
        if (!System.getenv().containsKey(name) || System.getenv(name).isBlank()) {
            environment.put(name, value);
        }
    }

    private static RubyScript loadScript(String[] args, Path projectRoot) throws IOException {
        if (args.length > 0) {
            Path path = Path.of(args[0]);
            if (!path.isAbsolute() && !Files.isRegularFile(path)) {
                path = projectRoot.resolve(path);
            }
            return readScript(path);
        }

        Path[] candidates = {
            projectRoot.resolve("app.rb"),
            projectRoot.resolve("src/main/ruby/app.rb"),
            projectRoot.resolve("../Resources/app.rb").normalize()
        };

        for (Path candidate : candidates) {
            if (Files.isRegularFile(candidate)) {
                return readScript(candidate);
            }
        }

        throw new IOException("Could not find Ruby entrypoint.");
    }

    private static RubyScript readScript(Path path) throws IOException {
        Path normalized = path.toAbsolutePath().normalize();
        return new RubyScript(normalized.toString(), Files.readString(normalized, StandardCharsets.UTF_8));
    }

    private record RubyScript(String name, String contents) {
    }

    private static String stackTrace(Throwable throwable) {
        StringWriter stringWriter = new StringWriter();
        throwable.printStackTrace(new PrintWriter(stringWriter));
        return stringWriter.toString();
    }

    private static void report(LaunchLog launchLog, String message) {
        launchLog.write(message);
        System.err.println(message);
    }

    private static final class LaunchLog {
        private final Path path;

        private LaunchLog() {
            path = Path.of(System.getProperty("user.home", "."))
                .resolve("Library")
                .resolve("Logs")
                .resolve("Watermarker")
                .resolve("launch.log");
        }

        private void write(String message) {
            try {
                Files.createDirectories(path.getParent());
                Files.writeString(
                    path,
                    Instant.now() + " " + message + System.lineSeparator(),
                    StandardCharsets.UTF_8,
                    StandardOpenOption.CREATE,
                    StandardOpenOption.APPEND
                );
            } catch (IOException ignored) {
                // Finder has no stderr; launch logging must never prevent startup.
            }
        }
    }
}
