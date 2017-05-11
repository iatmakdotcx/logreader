/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package mak.ui;

import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.util.ArrayList;
import mak.capture.DBLogPicker;
import mak.capture.DBSqlBuilder;
import mak.tools.AesTools;

/**
 *
 * @author Chin
 */
public class JobMgr {    
	private static final JobMgr instance = new JobMgr();
    private static final String JOBFILENAME = "jobs.job";
    private ArrayList<Job> pool = new ArrayList<>();
    
    JobMgr(){
    	
    }
    public static JobMgr getInstance() {
    	return instance;
    }
    
    public void loadFromCfg(){
    	try {
            FileInputStream fis = new FileInputStream(JOBFILENAME);
            DataInputStream dis = new DataInputStream(fis);
            try
            {
                int jobCount = dis.readByte();
                for (int i = 0; i < jobCount; i++) {
                    byte[] SrcDBCon = new byte[dis.readInt()];
                    dis.read(SrcDBCon);

                    String aJobStr = AesTools.getInstance().Decode(SrcDBCon);
                    CreateNewJob(aJobStr);
                }	
            }finally{
                dis.close();
            }
        } catch (Exception e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }
    }
    
    public void saveToCfg() {
        try {
        
            FileOutputStream fis = new FileOutputStream(JOBFILENAME);
            DataOutputStream dis = new DataOutputStream(fis);
            try
            {
                dis.writeByte(1);
                
                
                	
            }finally{
                dis.close();
            }
        } catch (Exception e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }
                
    }
    
    public boolean CreateNewJob(String aJobStr){
    	Job job = new Job(aJobStr);     			
    	pool.add(job);
        return true;
    }
    
    public boolean CreateNewJob(DBLogPicker picker, DBSqlBuilder Sqlbuilder){
        
        
        return true;
    }
    
}
