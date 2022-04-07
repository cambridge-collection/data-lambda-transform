package uk.ac.cam.lib.cudl.awslambda.util;

import com.amazonaws.services.secretsmanager.AWSSecretsManager;
import com.amazonaws.services.secretsmanager.AWSSecretsManagerClientBuilder;
import com.amazonaws.services.secretsmanager.model.*;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.util.Base64;

public class SecretManager {

    private final static Properties properties = new Properties();

    private static String getSecretJSON(String secretName) {

        String region = properties.getProperty("REGION");

        // Create a Secrets Manager client
        AWSSecretsManager client  = AWSSecretsManagerClientBuilder.standard()
                .withRegion(region)
                .build();

        GetSecretValueRequest getSecretValueRequest = new GetSecretValueRequest()
                .withSecretId(secretName);
        GetSecretValueResult getSecretValueResult = client.getSecretValue(getSecretValueRequest);

        // Decrypts secret using the associated KMS key.
        // Depending on whether the secret is a string or binary
        if (getSecretValueResult.getSecretString() != null) {
            return getSecretValueResult.getSecretString();
        }
        else {
            return new String(Base64.getDecoder().decode(getSecretValueResult.getSecretBinary()).array());
        }

    }

    public static JsonNode getDBJSON() {

        ObjectMapper  objectMapper  =  new ObjectMapper();
        String secret = getSecretJSON(properties.getProperty("DB_SECRET_KEY"));

        try {
            return objectMapper.readTree(secret);
        } catch (JsonProcessingException e) {
            e.printStackTrace();
        }

        return null;
    }
}
