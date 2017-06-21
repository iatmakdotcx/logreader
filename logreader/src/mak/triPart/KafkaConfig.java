package mak.triPart;

import java.io.FileReader;
import java.io.IOException;
import java.util.Properties;

import org.apache.log4j.Logger;

import mak.constants.AppConstants;

public class KafkaConfig {
	private static Logger logger = Logger.getLogger(zk.class);
	private static KafkaConfig instance = new KafkaConfig();
	private static Properties initialProp = null;
	
	
	public static KafkaConfig getInstance() {
		return instance;
	}
	
	public boolean initCfg() {
		if (initialProp == null) {
			synchronized (this) {
				if (initialProp == null) {
					initialProp = new Properties();
					FileReader fr;
					try {
						fr = new FileReader(AppConstants.KAFKA_CONFIG_FILE);
						initialProp.load(fr);
					} catch (IOException e) {
						logger.error("≈‰÷√Œƒº˛∂¡»° ß∞‹£°", e);
						return false;
					}
				}
			}
		}
		return true;
	}
	
	public String getCfgValue(String key){
		if (initCfg()) {
			return initialProp.getProperty(key);
		}
		return "";
	}
	
	public String getBootstrapServers(){
		return getCfgValue("bootstrap.servers");
	}
}
