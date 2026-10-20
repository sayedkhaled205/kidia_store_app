import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.Path;
import java.security.CodeSigner;
import java.security.KeyStore;
import java.security.MessageDigest;
import java.security.PrivateKey;
import java.security.cert.X509Certificate;
import java.util.HashSet;
import java.util.HexFormat;
import java.util.Set;
import java.util.jar.JarFile;

/** Uses JDK verifiers, not certificate names or jarsigner's warning-prone exit code. */
class VerifyAndroidSigning {
    private static X509Certificate leaf;

    private static String certificate(X509Certificate value) throws Exception {
        value.checkValidity();
        String digest = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value.getEncoded()));
        if (leaf == null) leaf = value;
        return digest;
    }

    private static String json(String value) {
        return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"")
            .replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t") + "\"";
    }

    public static void main(String[] args) {
        try {
            if (args.length != 2) throw new IllegalArgumentException("Expected keystore or bundle and its file.");
            Set<String> signers = new HashSet<>();
            int checked = 0;
            if (args[0].equals("keystore")) {
                char[] storePassword = System.getenv("CM_KEYSTORE_PASSWORD").toCharArray();
                char[] keyPassword = System.getenv("CM_KEY_PASSWORD").toCharArray();
                String alias = System.getenv("CM_KEY_ALIAS");
                KeyStore store = KeyStore.getInstance(Path.of(args[1]).toFile(), storePassword);
                if (!(store.getKey(alias, keyPassword) instanceof PrivateKey)) {
                    throw new IllegalArgumentException("Registered alias has no accessible private key.");
                }
                signers.add(certificate((X509Certificate) store.getCertificate(alias)));
            } else if (args[0].equals("bundle")) {
                try (JarFile jar = new JarFile(args[1], true)) {
                    Set<String> names = new HashSet<>();
                    var entries = jar.entries();
                    while (entries.hasMoreElements()) {
                        var entry = entries.nextElement();
                        String name = entry.getName();
                        if (!names.add(name)) throw new SecurityException("Duplicate bundle entry.");
                        if (entry.isDirectory()) continue;
                        // Reading to EOF triggers Java's cryptographic JAR verification.
                        try (InputStream input = jar.getInputStream(entry)) {
                            input.transferTo(OutputStream.nullOutputStream());
                        }
                        if (name.equalsIgnoreCase("META-INF/MANIFEST.MF") ||
                            name.matches("(?i)^META-INF/[^/]+\\.(SF|RSA|DSA|EC)$")) continue;
                        CodeSigner[] entrySigners = entry.getCodeSigners();
                        if (entrySigners == null || entrySigners.length != 1) {
                            throw new SecurityException("Every bundle payload entry must have one verified signer.");
                        }
                        signers.add(certificate((X509Certificate) entrySigners[0].getSignerCertPath().getCertificates().get(0)));
                        checked++;
                    }
                }
                if (checked == 0) throw new SecurityException("The bundle contains no verified payload.");
            } else {
                throw new IllegalArgumentException("Unknown verification operation.");
            }
            if (signers.size() != 1) throw new SecurityException("The artifact has inconsistent signing identities.");
            System.out.println("{\"certificate_sha256\":" + json(signers.iterator().next()) +
                ",\"subject\":" + json(leaf.getSubjectX500Principal().getName()) +
                ",\"expires_at\":" + json(leaf.getNotAfter().toInstant().toString()) +
                ",\"verified_entries\":" + checked + "}");
        } catch (Exception failure) {
            // Do not leak keystore paths, aliases, passwords, or tool output in CI errors.
            System.err.println("Android cryptographic signing verification failed (" + failure.getClass().getSimpleName() + ").");
            System.exit(1);
        }
    }
}
