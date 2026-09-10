package com.camertron.watermarker;

import java.lang.reflect.Field;
import java.lang.reflect.Method;

import org.graalvm.nativeimage.hosted.Feature;

public final class JCodingsNativeImageFeature implements Feature {
    @Override
    public String getDescription() {
        return "Initializes Truffle language metadata before TruffleRuby encodings load";
    }

    @Override
    public void afterRegistration(AfterRegistrationAccess access) {
        initializeLanguageCache(access.getApplicationClassLoader());
    }

    @Override
    public void beforeAnalysis(BeforeAnalysisAccess access) {
        ClassLoader classLoader = access.getApplicationClassLoader();
        initializeLanguageCache(classLoader);
        initializeJCodings(classLoader);
    }

    private static void initializeLanguageCache(ClassLoader classLoader) {
        try {
            Class<?> languageCache = Class.forName(
                "com.oracle.truffle.polyglot.LanguageCache",
                true,
                classLoader
            );
            Method initializer = languageCache.getDeclaredMethod(
                "initializeNativeImageState",
                ClassLoader.class
            );
            initializer.setAccessible(true);
            initializer.invoke(null, classLoader);
        } catch (ReflectiveOperationException exception) {
            throw new IllegalStateException("Could not initialize Truffle language cache", exception);
        }
    }

    private static void initializeJCodings(ClassLoader classLoader) {
        try {
            Class<?> jCodings = Class.forName(
                "com.oracle.truffle.api.strings.JCodings",
                true,
                classLoader
            );
            Field enabled = jCodingsEnabledField(jCodings);
            enabled.setAccessible(true);

            if (!Boolean.TRUE.equals(enabled.get(null))) {
                throw new IllegalStateException("Truffle JCodings initialized disabled");
            }
        } catch (ReflectiveOperationException exception) {
            throw new IllegalStateException("Could not initialize Truffle JCodings", exception);
        }
    }

    private static Field jCodingsEnabledField(Class<?> jCodings) throws NoSuchFieldException {
        try {
            return jCodings.getDeclaredField("JCODINGS_ENABLED");
        } catch (NoSuchFieldException exception) {
            return jCodings.getDeclaredField("ENABLED");
        }
    }
}
