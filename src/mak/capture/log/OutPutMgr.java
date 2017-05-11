/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package mak.capture.log;

import java.util.ArrayList;

/**
 *
 * @author Chin
 */
public class OutputMgr implements Output {
    private ArrayList<Output> sl = new ArrayList<>();

    public OutputMgr(String logType){
    	String[] typs = logType.split(",");
    	for (String string : typs) {
			if (string.toLowerCase().trim().equals("console")) {
				addOutput(ConsoleOutput.getInstance());
			}else if (string.toLowerCase().trim().equals("app")) {
				addOutput(MainWndOutput.getInstance());
			}else if (string.toLowerCase().trim().equals("file")) {
				//TODO:文件的输出定义
				throw new UnsupportedOperationException("Not supported yet."); 
			}
		}
    	if (sl.size()==0) {
    		addOutput(ConsoleOutput.getInstance());
		}
    }
	public OutputMgr(OutputTypes... type) {	
		for (OutputTypes outputTypes : type) {
			switch (outputTypes) {
			case Console:
				addOutput(ConsoleOutput.getInstance());
				break;
			case File:
				//TODO:文件的输出定义
				throw new UnsupportedOperationException("Not supported yet."); 
				//break;
			case MainWnd:
				addOutput(MainWndOutput.getInstance());
				break;
			}
		}
		if (sl.size()==0) {
    		addOutput(ConsoleOutput.getInstance());
		}
	}

    public boolean addOutput(Output opt){
    	for (Output output : sl) {
			if (output.equals(opt)) {
				return false;
			}
		}
    	sl.add(opt); 
    	return true;
    }
    @Override
    public void Info(String var1) {
        for (Output output : sl) {
        	output.Info(var1);
		}
    }

    @Override
    public void Warning(String var1) {
    	for (Output output : sl) {
        	output.Warning(var1);
		}
    }

    @Override
    public void Error(String var1) {
    	for (Output output : sl) {
        	output.Error(var1);
		}
    }

}
