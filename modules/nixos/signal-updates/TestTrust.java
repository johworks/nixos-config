import java.nio.file.Path;
import java.security.KeyStore;
import java.security.cert.X509Certificate;
import java.util.Arrays;
import java.util.Set;
import java.util.stream.Collectors;
import javax.net.ssl.TrustManagerFactory;
import javax.net.ssl.X509TrustManager;

class TestTrust {
    public static void main(String[] args) throws Exception {
        var store = KeyStore.getInstance(Path.of(args[0]).toFile(), "changeit".toCharArray());
        var expected = store.aliases().asIterator();
        var certificates = new java.util.HashSet<X509Certificate>();
        expected.forEachRemaining(alias -> {
            try {
                certificates.add((X509Certificate) store.getCertificate(alias));
            } catch (Exception error) {
                throw new RuntimeException(error);
            }
        });
        var factory = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
        factory.init((KeyStore) null);
        var manager = (X509TrustManager) Arrays.stream(factory.getTrustManagers())
            .filter(m -> m instanceof X509TrustManager).findFirst().orElseThrow();
        var issuers = Set.of(manager.getAcceptedIssuers());
        if (!issuers.equals(certificates) || issuers.size() < 100) {
            throw new AssertionError("Java default trust does not match the host-derived store: "
                + issuers.size() + " accepted, " + certificates.size() + " expected");
        }
        var subjects = issuers.stream().map(c -> c.getSubjectX500Principal().getName())
            .collect(Collectors.joining("\n"));
        for (String name : new String[]{"AAA Certificate Services", "emSign ECC Root CA - G3",
                                       "emSign Root CA - C1", "emSign ECC Root CA - C3"}) {
            if (subjects.contains("CN=" + name)) {
                throw new AssertionError("Distrusted CA remains accepted: " + name);
            }
        }
        System.out.println("Java default trust matches " + issuers.size() + " host CA certificates.");
    }
}
