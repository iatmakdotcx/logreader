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

import mak.tools.AesTools;
import mak.triPart.zk;

/**
 *
 * @author Chin
 */
public class JobMgr {

    private static final JobMgr instance = new JobMgr();
    private static final String JOBFILENAME = "jobs.job";
    private ArrayList<Job> pool = new ArrayList<>();
    private zk zkClient = new zk();
    
    JobMgr() {

    }

    public ArrayList<Job> JobList(){
        return pool;
    }
    
    public static JobMgr getInstance() {
        return instance;
    }
    
    public void RefreshJob() {
    	zkClient.initCfg("");
    	String jobStr = zkClient.getPathValue("/mak/DBlog/jobs");
        String[] jobKeys = jobStr.split(",");
        
        for (int i = 0; i < jobKeys.length; i++) {
            String key = jobKeys[i];
            if (key.isEmpty()) {
				continue;
			}
            String ConStr = zkClient.getConStr(key);
            CreateNewJob(ConStr);
        }
	}
    
    public boolean CreateNewJob(String aJobStr) {
        Job job = new Job(aJobStr);
        pool.add(job);
        return true;
    }
    
    public void Start(int idx){
    	if (idx>=0 && idx<pool.size()) {
			pool.get(idx).Start();
		}	
    }
    public void Start(String jobkey){
    	for (Job job : pool) {
    		if (job.jobKey.equals(jobkey)) {
				job.Start();
			}
		}
    }
    
    public void Stop(int idx){
    	if (idx>=0 && idx<pool.size()) {
    		pool.get(idx).Stop();
    	}
    }
    
    public void Stop(String jobkey){
    	for (Job job : pool) {
    		if (job.jobKey.equals(jobkey)) {
				job.Stop();
			}
		}
    }
    
    public void StartAll(){
    	for (Job job : pool) {
    		job.Start();
		}
    }
    
    public void StopAll(){
    	for (Job job : pool) {
    		job.Stop();
		}
    }
    
    @Deprecated
    public void loadFromCfg() {
        try {
            FileInputStream fis = new FileInputStream(JOBFILENAME);
            DataInputStream dis = new DataInputStream(fis);
            try {
                int jobCount = dis.readByte();
                for (int i = 0; i < jobCount; i++) {
                    byte[] SrcDBCon = new byte[dis.readInt()];
                    dis.read(SrcDBCon);

                    String aJobStr = AesTools.getInstance().Decode(SrcDBCon);
                    CreateNewJob(aJobStr);
                }
            } finally {
                dis.close();
                fis.close();
            }
        } catch (Exception e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }
    }

    @Deprecated
    public void saveToCfg() {
        try {
            FileOutputStream fis = new FileOutputStream(JOBFILENAME);
            DataOutputStream dis = new DataOutputStream(fis);
            try {
                dis.writeByte(pool.size());
                for (Job job : pool) {
                    byte[] TmpBuf = AesTools.getInstance().Encode(job.aJobStr).getBytes();
                    dis.writeInt(TmpBuf.length);
                    dis.write(TmpBuf);
                }
                dis.flush();
            } finally {
                dis.close();
                fis.close();
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Deprecated
    public boolean CreateNewJob(String ConStr, String ConDst, String cfgStr) {
        Job job = new Job(ConStr, ConDst, cfgStr);
        pool.add(job);
        return true;
    }

}
