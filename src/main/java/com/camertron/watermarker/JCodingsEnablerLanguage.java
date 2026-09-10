package com.camertron.watermarker;

import com.oracle.truffle.api.TruffleLanguage;

@TruffleLanguage.Registration(
    id = "watermarker-encodings",
    name = "Watermarker Encodings",
    implementationName = "Watermarker",
    internal = true,
    interactive = false,
    needsAllEncodings = true
)
public final class JCodingsEnablerLanguage extends TruffleLanguage<Void> {
    public JCodingsEnablerLanguage() {
    }

    @Override
    protected Void createContext(Env env) {
        return null;
    }
}
