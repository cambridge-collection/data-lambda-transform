package uk.ac.cam.lib.cudl.awslambda.util;

import org.apache.commons.dbcp.BasicDataSource;
import org.apache.commons.dbutils.DbUtils;

import java.sql.Connection;
import java.sql.SQLException;

public class DBCPDataSource {
    
    private static BasicDataSource ds = new BasicDataSource();
    
    static {
        Properties properties = new Properties();
        String driver = properties.getProperty("DB_JDBC_DRIVER");
        String url = properties.getProperty("DB_URL");
        String username = properties.getProperty("DB_USERNAME");
        String password = properties.getProperty("DB_PASSWORD");

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