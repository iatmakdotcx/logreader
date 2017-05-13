package mak.ui;

import mak.capture.DBLogPicker;
import mak.capture.mssql.MsLogPicker;
import mak.tools.StringUtil;

public class Job {
    public String aJobStr;
    public JobState state = JobState.Uninitialized;

    private DBLogPicker Logpicker = null;

    public Job(String aJobStr) {
        this.aJobStr = aJobStr;
        CreateSrc();
        CreateDst();
        state = JobState.Stoped;
    }
    
    public Job(String ConSrc, String Condst, String cfgStr) {
        StringBuilder sbsb = new StringBuilder();
        sbsb.append("<root><src>");
        sbsb.append(ConSrc);
        sbsb.append("</src><dst>");
        sbsb.append(Condst);
        sbsb.append("</dst><cfg>");
        sbsb.append(cfgStr);
        sbsb.append("</cfg></root>");
        this.aJobStr = sbsb.toString();
        CreateSrc();
        CreateDst();
        
        state = JobState.Stoped;
    }
    
    public boolean CreateSrc() {
        String srcStr = StringUtil.getXmlValueFromStr(aJobStr, "src");
        String srcType = StringUtil.getXmlValueFromStr(srcStr, "type");
        if (srcType.equals("DB")) {
            String DBType = StringUtil.getXmlValueFromStr(srcStr, "subtype");
            if (DBType.equals("mssql")) {
                Logpicker = new MsLogPicker(srcStr);
            } else if (DBType.equals("mysql")) {
                //TODO:  mysql picker
                throw new UnsupportedOperationException("Not supported yet.");
            } else if (DBType.equals("oracle")) {
                //TODO:  oracle picker
                throw new UnsupportedOperationException("Not supported yet.");
            } else {
                throw new UnsupportedOperationException("Not supported yet.");
            }

        } else if (srcType.equals("kafka")) {
            //TODO:Read From Kafka
            throw new UnsupportedOperationException("Not supported yet.");
        } else {
            throw new UnsupportedOperationException("Not supported yet.");
        }

        return true;
    }

    public boolean CreateDst() {
        String dstStr = StringUtil.getXmlValueFromStr(aJobStr, "dst");
        String dstType = StringUtil.getXmlValueFromStr(dstStr, "type");
        if (dstType.equals("DB")) {
            String logType = StringUtil.getXmlValueFromStr(dstStr, "subtype");
            if (logType.equals("mssql")) {

            } else if (logType.equals("bin")) {
                throw new UnsupportedOperationException("Not supported yet.");
            }
        } else if (dstType.equals("log")) {
            String logType = StringUtil.getXmlValueFromStr(dstStr, "subtype");
            if (logType.equals("sql")) {

            } else if (logType.equals("bin")) {
                throw new UnsupportedOperationException("Not supported yet.");
            }
        } else if (dstType.equals("kafka")) {
            String logType = StringUtil.getXmlValueFromStr(dstStr, "subtype");
            //TODO:Write to Kafka
            if (logType.equals("sql")) {
                throw new UnsupportedOperationException("Not supported yet.");
            } else if (logType.equals("bin")) {
                throw new UnsupportedOperationException("Not supported yet.");
            }
        } else {
            throw new UnsupportedOperationException("Not supported yet.");
        }

        return true;
    }

    public void Stop() {
        Logpicker.Terminate();
        state = JobState.Stoped;
    }

    public boolean Start() {
        if (Logpicker.init()) {
            Thread thread = new Thread(Logpicker, "Logpicker");
            thread.start();
        }
        state = JobState.Running;
        return true;
    }

}
