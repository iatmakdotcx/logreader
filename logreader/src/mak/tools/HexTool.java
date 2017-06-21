package mak.tools;

import java.io.ByteArrayOutputStream;
import java.nio.charset.Charset;

import mak.constants.AppConstants;

public class HexTool {
	 static private char[] HEX = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};

	    /**
	     * Static class dummy constructor.
	     */
	    private HexTool() {
	    }

	    /**
	     * Turns a byte into a hexadecimal string.
	     * 
	     * @param byteValue The byte to convert.
	     * @return The hexadecimal representation of <code>byteValue</code>
	     */
	    public static String toString(byte byteValue) {
	        int tmp = byteValue << 8;
	        char[] retstr = new char[]{HEX[(tmp >> 12) & 0x0F], HEX[(tmp >> 8) & 0x0F]};
	        return String.valueOf(retstr);
	    }

	    /**
	     * Turns a <code>org.apache.mina.common.ByteBuffer</code> into a
	     * hexadecimal string.
	     * 
	     * @param buf The <code>org.apache.mina.common.ByteBuffer</code> to
	     *            convert.
	     * @return The hexadecimal representation of <code>buf</code>
	     */
//	    public static String toString(ByteBuffer buf) {
//	        buf.flip();
//	        byte arr[] = new byte[buf.remaining()];
//	        buf.get(arr);
//	        String ret = toString(arr);
//	        buf.flip();
//	        buf.put(arr);
//	        return ret;
//	    }

	    /**
	     * Turns an integer into a hexadecimal string.
	     * 
	     * @param intValue The integer to transform.
	     * @return The hexadecimal representation of <code>intValue</code>.
	     */
	    public static String toString(int intValue) {
	        return Integer.toHexString(intValue);
	    }

	    /**
	     * Turns an array of bytes into a hexadecimal string.
	     * 
	     * @param bytes The bytes to convert.
	     * @return The hexadecimal representation of <code>bytes</code>
	     */
	    public static String toString(byte[] bytes) {
	        StringBuilder hexed = new StringBuilder();
	        for (int i = 0; i < bytes.length; i++) {
	            hexed.append(toString(bytes[i]));
	            hexed.append(' ');
	        }
	        return hexed.substring(0, hexed.length() - 1);
	    }

	    /**
	     * Turns an array of bytes into a ASCII string. Any non-printable characters
	     * are replaced by a period (<code>.</code>)
	     * 
	     * @param bytes The bytes to convert.
	     * @return The ASCII hexadecimal representation of <code>bytes</code>
	     */
	    public static String toStringFromAscii(byte[] bytes) {
	        byte[] ret = new byte[bytes.length];
	        for (int x = 0; x < bytes.length; x++) {
	            if (bytes[x] < 32 && bytes[x] >= 0) {
	                ret[x] = '.';
	            } else {
	                ret[x] = bytes[x];
	            }
	        }
	        try {
	            String str = new String(ret, AppConstants.ASCII);
	            return str;
	        } catch (Exception e) {
	        }
	        return "";
	    }

	    public static String toStringFromAscii(byte[] bytes,Charset charset) {
	        try {
	            String str = new String(bytes, charset);
	            return str;
	        } catch (Exception e) {
	        }
	        return "";
	    }

	    public static String toStringFromUnicode(byte[] bytes) {
	    	int len = bytes.length / 2;
	        char[] ret = new char[len];
	        for (int x = 0; x < len; x++) {
	        	ret[x] = (char) ((bytes[x * 2]&0xFF) | (bytes[x*2+1]<<8));
	        }
	        try {
	            return String.valueOf(ret);
	        } catch (Exception e) {
	        }
	        return "";
	    }
	    
	    public static String toPaddedStringFromAscii(byte[] bytes) {
	        String str = toStringFromAscii(bytes);
	        StringBuilder ret = new StringBuilder(str.length() * 3);
	        for (int i = 0; i < str.length(); i++) {
	            ret.append(str.charAt(i));
	            ret.append("  ");
	        }
	        return ret.toString();
	    }

	    /**
	     * Turns an hexadecimal string into a byte array.
	     * 
	     * @param hex The string to convert.
	     * @return The byte array representation of <code>hex</code>
	     */
	    public static byte[] getByteArrayFromHexString(String hex) {
	        ByteArrayOutputStream baos = new ByteArrayOutputStream();
	        int nexti = 0;
	        int nextb = 0;
	        boolean highoc = true;
	        outer:
	        for (;;) {
	            int number = -1;
	            while (number == -1) {
	                if (nexti == hex.length()) {
	                    break outer;
	                }
	                char chr = hex.charAt(nexti);
	                if (chr >= '0' && chr <= '9') {
	                    number = chr - '0';
	                } else if (chr >= 'a' && chr <= 'f') {
	                    number = chr - 'a' + 10;
	                } else if (chr >= 'A' && chr <= 'F') {
	                    number = chr - 'A' + 10;
	                } else {
	                    number = -1;
	                }
	                nexti++;
	            }
	            if (highoc) {
	                nextb = number << 4;
	                highoc = false;
	            } else {
	                nextb |= number;
	                highoc = true;
	                baos.write(nextb);
	            }
	        }
	        return baos.toByteArray();
	    }
}
