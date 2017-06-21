package mak.database;

import java.io.IOException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.Collection;
import java.util.LinkedList;
import java.util.Properties;

public class DatabaseConnection {

    private static ThreadLocal<Connection> con = new ThreadLocalConnection();
    private static Properties props = null;

    public static Connection getConnection() {
        if (props == null) {
        	TryGetDefProps();
        	if (props == null) {
        		throw new RuntimeException("DatabaseConnection not initialized");
        	}
        }
        return (Connection) con.get();
    }

    public static boolean isInitialized() {
        return props != null;
    }

    public static void setProps(Properties aProps) {
        props = aProps;
    }
    private static synchronized void TryGetDefProps() {
        if (props==null) {
        	try {
        		java.net.URL FileUrl = DatabaseConnection.class.getClassLoader().getResource("..\\db.properties");
        		if (FileUrl != null) {
	        		java.io.InputStream is = FileUrl.openStream();  
	        		Properties dbProp = new Properties();
	        		dbProp.load(is);
	        		setProps(dbProp);
	        		is.close();
        		}
			} catch (IOException e1) {
				e1.printStackTrace();
			} 
		}
    }

    public static void closeAll() throws SQLException {
        for (Connection con : ThreadLocalConnection.allConnections) {
            con.close();
        }
    }

    private static class ThreadLocalConnection extends ThreadLocal<Connection> {

        public static Collection<Connection> allConnections = new LinkedList<Connection>();

        protected Connection initialValue() {
            String driver = DatabaseConnection.props.getProperty("driver");
            String url = DatabaseConnection.props.getProperty("url");
            String user = DatabaseConnection.props.getProperty("user");
            String password = DatabaseConnection.props.getProperty("password");
            if (driver == null || driver.isEmpty()) {
            	throw new RuntimeException("DatabaseConnection Properties driverName is null or Empty");
			}
            
            try {
                Class.forName(driver);
            } catch (ClassNotFoundException e) {
            	e.printStackTrace();
            }
            try {
                Connection con = DriverManager.getConnection(url, user, password);
                allConnections.add(con);
                return con;
            } catch (SQLException e) {
            	e.printStackTrace();
            }

            return null;
        }
    }
}