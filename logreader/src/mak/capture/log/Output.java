package mak.capture.log;

public interface Output {
    public void Info(String var1); 
    public default void Info(String var1, Object... args){
    	Info(String.format(var1, args));
    }
    
    public void Warning(String var1);
    public default void Warning(String var1, Object... args){
    	Warning(String.format(var1, args));
    }
    
    public void Error(String var1);
    public default void Error(String var1, Object... args){
    	Error(String.format(var1, args));
    }
}
