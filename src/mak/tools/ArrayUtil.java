package mak.tools;

public class ArrayUtil {
	
	
	public static short getBytesShort(byte[] byf,int idx){
		int tmpInt = 0;
		for (int i = idx; i < Math.min(idx+2, byf.length); i++) {
			tmpInt = (tmpInt | ((byf[i]&0xFF) << ((i-idx)*8)));
		}
		return (short)tmpInt;
	}
	
	public static int getBytesInt(byte[] byf,int idx){
		int tmpInt = 0;
		for (int i = idx; i < Math.min(idx+4, byf.length); i++) {
			tmpInt = (tmpInt | ((byf[i]&0xFF) << ((i-idx)*8)));
		}
		return tmpInt;
	}
	
	public static int getBytesInt(byte[] byf,int idx, int len){
		int tmpInt = 0;
		for (int i = idx; i < Math.min(idx+len, byf.length); i++) {
			tmpInt = (tmpInt | ((byf[i]&0xFF) << ((i-idx)*8)));
		}
		return tmpInt;
	}
	
	public static long getByteslong(byte[] byf,int idx){
		long tmpInt = 0;
		for (int i = idx; i < Math.min(idx+8, byf.length); i++) {
			tmpInt = (tmpInt + ((long)(byf[i] & 0xFF) << ((i-idx)*8)));
		}
		return tmpInt;
	}
	
	public static long getByteslong(byte[] byf,int idx, int len){
		long tmpInt = 0;
		for (int i = idx; i < Math.min(idx+len, byf.length); i++) {
			tmpInt = (tmpInt + ((long)(byf[i] & 0xFF) << ((i-idx)*8)));
		}
		return tmpInt;
	}
}
