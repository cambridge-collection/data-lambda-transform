package uk.ac.cam.lib.cudl.awslambda.model;

public class ReceivedSQSMessage {

    public enum eventTypes { ObjectCreated, ObjectRemoved }
    private final eventTypes eventType;
    private final String s3Bucket;
    private final String s3Key;

    public ReceivedSQSMessage(eventTypes eventType, String s3Bucket, String s3Key) {
        this.eventType = eventType;
        this.s3Bucket = s3Bucket;
        this.s3Key = s3Key;
    }

    public eventTypes getEventType() {
        return eventType;
    }

    public String getS3Bucket() {
        return s3Bucket;
    }

    public String getS3Key() {
        return s3Key;
    }

}
