package mak.server;

import mak.ui.Frm_jobCfg;
import org.apache.log4j.PropertyConfigurator;

public class JobConfigUI {
	public static void main(String[] args) {
            PropertyConfigurator.configure("config/log4j.properties");
            new Frm_jobCfg().setVisible(true);
	}

}
