package mak.capture.log;

import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Date;

public class ConsoleOutput implements Output {
    private final DateFormat format = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
    private static ConsoleOutput instance = new ConsoleOutput();
    
    ConsoleOutput(){
    	
    }
    
    public static ConsoleOutput getInstance(){
    	return instance;
    }
    
    
	@Override
	public void Info(String var1) {
            // TODO Auto-generated method stub
            Date date = new Date();
            String time = format.format(date);

            System.out.println(time + "  :  " + var1);
	}

	@Override
	public void Warning(String var1) {
            // TODO Auto-generated method stub
            Date date = new Date();
            String time = format.format(date);
            System.out.println(time + "  :  " + var1);
	}

	@Override
	public void Error(String var1) {
            // TODO Auto-generated method stub
            Date date = new Date();
            String time = format.format(date);
            System.err.println(time + "  :  " + var1);
	}


}
