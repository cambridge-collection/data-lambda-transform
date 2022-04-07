package uk.ac.cam.lib.cudl.awslambda.util;

import com.fasterxml.jackson.databind.JsonNode;
import org.apache.commons.dbcp.BasicDataSource;
import org.apache.commons.dbutils.DbUtils;

import java.sql.Connection;
import java.sql.SQLException;

public class DBCPDataSource {
    
    private static BasicDataSource ds = new BasicDataSource();
    
    static {

        JsonNode secretJSON = SecretManager.getDBJSON();

        Properties properties = new Properties();
        String driver = properties.getProperty("DB_JDBC_DRIVER");
        String url = properties.getProperty("DB_URL");
        String username = secretJSON.get("username").textValue();
        String password = secretJSON.get("password").textValue();
        String host = secretJSON.get("host").textValue();
        int port = secretJSON.get("port").asInt();

        url = url.replaceAll("<HOST>", host);
        url = url.replaceAll("<PORT>", String.valueOf(port));

        DbUtils.loadDriver(driver);
        ds.setUrl(url);
        ds.setUsername(username);
        ds.setPassword(password);
        ds.setMinIdle(5);
        ds.setMaxIdle(10);
        ds.setMaxOpenPreparedStatements(100);
    }
    
    public static Connection getConnection() throws SQLException {
        return ds.getConnection();
    }
    
    private DBCPDataSource(){ }
}