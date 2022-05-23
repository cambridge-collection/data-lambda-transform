package uk.ac.cam.lib.cudl.awslambda.util;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.xml.transform.TransformerConfigurationException;
import javax.xml.transform.TransformerException;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.stream.StreamSource;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.stream.Stream;

public class TranscriptionHelper {

    private final String pagifyXSLT;
    private final String msTEIXSLT;
    private final XSLTHelper xsltHelper;
    private static final Logger logger = LoggerFactory.getLogger(TranscriptionHelper.class);

    public TranscriptionHelper() throws TransformerConfigurationException {
        Properties properties = new Properties();

        pagifyXSLT = properties.getProperty("TRANSCRIPTION_PAGIFY_XSLT");
        msTEIXSLT = properties.getProperty("TRANSCRIPTION_MSTEI_XSLT");
        xsltHelper = new XSLTHelper(pagifyXSLT+","+msTEIXSLT);
    }

    public Set<String> chunk(StreamSource streamSource, String outputDir, int num_chunks) throws TransformerException, IOException {

        return pagify(streamSource, outputDir, num_chunks);

    }

    public Set<String> pagify(StreamSource srcStream, String outputDir, int num_chunks) throws IOException, TransformerException {

        Files.createDirectories(Path.of(outputDir));

        logger.info("paginating StreamToFiles: src:"+srcStream+" outputDir:"+outputDir+" chunks:"+num_chunks);
        Map<String, String> params = new HashMap<>();
        params.put("num_chunks", String.valueOf(num_chunks));
        params.put("dest_dir", outputDir);

        // Stream result
        StreamResult streamResult = new StreamResult(new File(outputDir+"/output"));

        xsltHelper.transform(srcStream, streamResult, xsltHelper.getTemplate(pagifyXSLT), params);

        logger.info("files: "+Stream.of(Objects.requireNonNull(new File(outputDir).listFiles())).map(File::getPath).collect(Collectors.toSet()));

        try(var allFiles = Files.walk(Paths.get(outputDir))) {
            return allFiles.filter(Files::isRegularFile)
                    .map(Path::toString)
                    .filter(file -> file.endsWith(".xml"))
                    .collect(Collectors.toSet());
        }

    }

    public void msTEI(StreamSource streamSource, StreamResult streamResult) throws TransformerException {

        xsltHelper.transform(streamSource, streamResult, xsltHelper.getTemplate(msTEIXSLT), new HashMap<>());
    }

}
