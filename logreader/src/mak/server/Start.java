package mak.server;

import org.apache.log4j.PropertyConfigurator;

import mak.ui.JobMgr;

public class Start {

	public static void main(String[] args) {
		PropertyConfigurator.configure("config/log4j.properties");	
		JobMgr.getInstance().RefreshJob();
		JobMgr.getInstance().Start("20170522194326941");
	}
}