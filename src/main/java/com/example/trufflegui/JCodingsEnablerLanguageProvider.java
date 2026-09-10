package com.example.trufflegui;

import java.util.Collection;
import java.util.List;

import com.oracle.truffle.api.TruffleLanguage;
import com.oracle.truffle.api.provider.TruffleLanguageProvider;

@TruffleLanguage.Registration(
    id = "watermarker-encodings",
    name = "Watermarker Encodings",
    implementationName = "Watermarker",
    internal = true,
    interactive = false,
    needsAllEncodings = true
)
public final class JCodingsEnablerLanguageProvider extends TruffleLanguageProvider {
    public JCodingsEnablerLanguageProvider() {
    }

    @Override
    protected String getLanguageClassName() {
        return JCodingsEnablerLanguage.class.getName();
    }

    @Override
    protected Object create() {
        return new JCodingsEnablerLanguage();
    }

    @Override
    protected Collection<String> getServicesClassNames() {
        return List.of();
    }

    @Override
    protected List<?> createFileTypeDetectors() {
        return List.of();
    }
}
