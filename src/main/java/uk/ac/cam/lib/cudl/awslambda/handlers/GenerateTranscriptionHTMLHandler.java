package uk.ac.cam.lib.cudl.awslambda.handlers;

import com.amazonaws.services.lambda.runtime.Context;
import org.apache.commons.io.FileUtils;
import org.apache.commons.io.FilenameUtils;
import org.apache.commons.lang3.StringUtils;
import org.json.JSONArray;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import uk.ac.cam.lib.cudl.awslambda.input.S3Input;
import uk.ac.cam.lib.cudl.awslambda.output.S3Output;
import uk.ac.cam.lib.cudl.awslambda.util.LambdaInvoker;
import uk.ac.cam.lib.cudl.awslambda.util.Properties;
import uk.ac.cam.lib.cudl.awslambda.util.TranscriptionHelper;

import javax.xml.transform.TransformerConfigurationException;
import javax.xml.transform.TransformerException;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.stream.StreamSource;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.stream.Stream;

/**
 * Triggered by a edit from cudl data in s3.  One event s3 is sent per file edited.  These are put into
 * a queue in SQS which can batch events in groups of up to 10.
 * NOTE DO NOT WRITE TO SAME S3 WHICH CONTAINS THE TRIGGER as this could cause an expensive loop.
 * so do not write to the data directory.
 */
public class GenerateTranscriptionHTMLHandler extends AbstractRequestHandler {

    private static final Logger logger = LoggerFactory.getLogger(GenerateTranscriptionHTMLHandler.class);

    private final long LARGE_FILE_LIMIT; // Any larger files will be chunked.
    private final int chunks; // Number of chunks to use
    public final String functionName;
    private final TranscriptionHelper transcriptionHelper;
    private final S3Output s3Output;
    private final S3Input s3Input;
    private final LambdaInvoker invoker;
    private final String tmpDir;
    private final String dstPrefix;
    private final String dstBucket;
    private final String pathToLayerResources="/opt/xslt/transcription/web/";

    public GenerateTranscriptionHTMLHandler() throws TransformerConfigurationException {

        Properties properties = new Properties();
        LARGE_FILE_LIMIT = Long.parseLong(properties.getProperty("TRANSCRIPTION_LARGE_FILE_LIMIT"));
        chunks = Integer.parseInt(properties.getProperty("TRANSCRIPTION_CHUNKS"));
        functionName = properties.getProperty("TRANSCRIPTION_FUNCTION_NAME");
        tmpDir = properties.getProperty("TMP_DIR");
        dstPrefix = properties.getProperty("TRANSCRIPTION_DST_PREFIX");
        dstBucket = properties.getProperty("TRANSCRIPTION_DST_BUCKET");

        s3Output = new S3Output(dstBucket,dstPrefix,"");
        s3Input = new S3Input();
        transcriptionHelper = new TranscriptionHelper();
        invoker = new LambdaInvoker();

    }

    @Override
    public String handlePutEvent(String srcBucket, String srcKey, Context context) throws IOException, TransformerException {

        logger.info("Put Event");
        String itemId = StringUtils.substringBefore(FilenameUtils.getBaseName(srcKey), ".");

        boolean chunkify = chunkify(srcBucket, srcKey);
        File outputDir = new File(tmpDir+context.getAwsRequestId()+"_"+Math.random());

        logger.info("chunkify: "+chunkify);
        if (chunkify) {

            StreamSource streamSource = new StreamSource(s3Input.getInputStream(srcBucket,srcKey));
            streamSource.setSystemId(new File(srcKey).getName()); // Required for pagify

            // Chunking uses pagify.xsl to generate chunks and then writes them to S3 and
            // invokes this function for each chunk.
            logger.info("chunking");
            File chunkOutputDir = new File(outputDir,"chunks");
            Files.createDirectories(chunkOutputDir.toPath());

            Set<String> chunks = transcriptionHelper.chunk(streamSource,
                    chunkOutputDir.getAbsolutePath()+"/output", this.chunks);

            // Check how many files come back.  If only 1 this file cannot be
            // pagified so move on to single file processing.
            if (chunks.size()>1) {

                for (String chunk : chunks) {
                    logger.info("chunk:" + chunk);

                    // write to S3
                    String dstPath = dstPrefix +"data/tei/"+itemId+"/"+FilenameUtils.getName(chunk);
                    s3Output.writeFromString(FileUtils.readFileToString(new File(chunk), StandardCharsets.UTF_8), dstPath);
                    logger.info("Written file out to s3: "+dstPath);

                    invokeLambda(dstBucket, dstPath);
                }
                return "Ok";
            }
        }

        // Single file processing, no chunking
        logger.info("no chunking needed");

        StreamSource streamSource = new StreamSource(s3Input.getInputStream(srcBucket,srcKey));
        streamSource.setSystemId(new File(srcKey).getName()); // Required for pagify

        File xmlOutputDir = new File(outputDir,"xml_output");
        Files.createDirectories(xmlOutputDir.toPath());

        Set<String> pages = transcriptionHelper.pagify(streamSource, xmlOutputDir.getAbsolutePath(), 1);
        File htmlOutputDir = new File(outputDir,"html_output");
        Files.createDirectories(htmlOutputDir.toPath());

        for (String page: pages) {
            File pageFile = new File(page);
            String pageName = FilenameUtils.getBaseName(pageFile.getName());
            File outputFile = new File(htmlOutputDir, pageName+".html");
            logger.info("page: "+page+" pagefile: "+pageFile.exists());
            logger.info("outputFile: "+outputFile+" htmlOutputDir: "+htmlOutputDir);

            StreamSource pageStreamSource = new StreamSource(pageFile);

            ByteArrayOutputStream os = new ByteArrayOutputStream();
            StreamResult streamResult = new StreamResult(os);

            transcriptionHelper.msTEI(pageStreamSource, streamResult);

            logger.info("Converted to html");

            // write to S3
            String dstPath = dstPrefix +"data/tei/"+itemId+"/"+pageName+".html";
            s3Output.writeFromStream(os,dstPath);
            logger.info("Written file out to s3: "+dstPath);
        }

        // copy resources if not already there
        copyResources();

      return "Ok";

    }

    private Set<String> listFiles(String dir, int depth) throws IOException {
        try (Stream<Path> stream = Files.walk(Paths.get(dir), depth)) {
            return stream
                    .filter(file -> !Files.isDirectory(file))
                    .map(Path::toString)
                    .collect(Collectors.toSet());
        }
    }

    private void copyResources() throws IOException {
        // If resources not already present at s3 transcription bucket
        for (String filePath: listFiles(pathToLayerResources, 10)) {
            String dstKey= filePath.replaceAll(pathToLayerResources,"");
            if (!s3Output.exists(dstBucket,dstKey)) {

                byte[] bytes = Files.readAllBytes(new File(filePath).toPath());
                ByteArrayOutputStream baos = new ByteArrayOutputStream(bytes.length);
                baos.write(bytes, 0, bytes.length);

                s3Output.writeFromStream(baos, dstBucket, dstKey);
            }
        }
    }

    @Override
    public String handleDeleteEvent(String srcBucket, String srcKey, Context context) {

        logger.info("Delete Event");
        String itemId = FilenameUtils.getBaseName(srcKey);
        String dstPath = dstPrefix +"data/tei/"+itemId+"/";
        // deletes every html file under this item id
        s3Output.deleteFromPath(dstPath);
        return "OK";
    }

    /**
     * Tests if object is large enough to need chunking or not.
     * (As very large files will timeout before the lambda limit)
     *
     * @param srcBucket
     * @param srcKey
     * @return
     */
    private boolean chunkify(String srcBucket, String srcKey) {
        var meta = S3Input.s3Client.getObjectMetadata(srcBucket, srcKey);
        return meta.getContentLength() >= LARGE_FILE_LIMIT;
    }

    /**
     * Invoke this lambda function again but with the specified object from s3
     * (used for chunking)
     * @param srcBucket
     * @param srcKey
     */
    private void invokeLambda(String srcBucket, String srcKey) {

        JSONObject bucket = new JSONObject();
        bucket.put("name", srcBucket);
        JSONObject key = new JSONObject();
        key.put("key", srcKey);
        JSONObject s3 = new JSONObject();
        s3.put("bucket", bucket);
        s3.put("object", key);
        JSONArray records = new JSONArray();
        JSONObject record = new JSONObject();
        record.put("s3", s3);
        record.put("eventName", "ObjectCreated:Put");
        records.put(record);
        JSONObject body = new JSONObject();
        body.put("Records", records);

        logger.info("Invoking lambda:"+functionName+" with chunk: "+body.toString());
        invoker.runWithPayload(functionName,body.toString());

    }
}
