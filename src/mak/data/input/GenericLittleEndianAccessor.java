package mak.data.input;

import java.io.ByteArrayOutputStream;

import mak.constants.AppConstants;

public class GenericLittleEndianAccessor implements LittleEndianAccessor{
	private ByteInputStream bs;
	/**
	 * 如果读取到数据末尾，之后的读取全部返回0不报EOF错
	 */
	public boolean PaddingZeroOnEof = false; 

    public GenericLittleEndianAccessor(ByteInputStream bs) {
        this.bs = bs;
    }
    
    public GenericLittleEndianAccessor(byte[] arr) {
        this.bs =  new ByteArrayByteStream(arr);
    }
    
	@Override
	public byte readByte() {
		if (PaddingZeroOnEof) {
			if (available() == 0) {
				return 0;
			}else{
				return (byte) this.bs.readByte();
			}
		}else{		
		    return (byte) this.bs.readByte();
		}
	}

	@Override
	public char readChar() {
		return (char) readShort();
	}

	@Override
	public short readShort() {
		int byte1 = this.readByte() & 0xFF;
        int byte2 = this.readByte() & 0xFF;
        return (short) ((byte2 << 8) + byte1);
	}

	@Override
	public int readInt() {
		int byte1 = this.readByte() & 0xFF;
        int byte2 = this.readByte() & 0xFF;
        int byte3 = this.readByte() & 0xFF;
        int byte4 = this.readByte() & 0xFF;
        return (byte4 << 24) + (byte3 << 16) + (byte2 << 8) + byte1;
	}

	@Override
	public long readLong() {
        long byte1 = this.readByte() & 0xFF;
        long byte2 = this.readByte() & 0xFF;
        long byte3 = this.readByte() & 0xFF;
        long byte4 = this.readByte() & 0xFF;
        long byte5 = this.readByte() & 0xFF;
        long byte6 = this.readByte() & 0xFF;
        long byte7 = this.readByte() & 0xFF;
        long byte8 = this.readByte() & 0xFF;

        return (byte8 << 56) + (byte7 << 48) + (byte6 << 40) + (byte5 << 32) + (byte4 << 24) + (byte3 << 16) + (byte2 << 8) + byte1;
	}

	@Override
	public void skip(int paramInt) {
		for (int x = 0; x < paramInt; x++) {
            readByte();
        }
	}

	@Override
	public byte[] read(int paramInt) {
		byte[] ret = new byte[paramInt];
        for (int x = 0; x < paramInt; x++) {
            ret[x] = readByte();
        }
        return ret;
	}

	@Override
	public float readFloat() {
		return Float.intBitsToFloat(readInt());
	}

	@Override
	public double readDouble() {
		return Double.longBitsToDouble(readLong());
	}

	@Override
	public String readAsciiString(int paramInt) {
		byte[] ret = new byte[paramInt];
        for (int x = 0; x < paramInt; x++) {
            ret[x] = readByte();
        }
        try {
            String str = new String(ret, AppConstants.ASCII);
            return str;
        } catch (Exception e) {
            System.err.println(e);
        }
        return "";
	}

	@Override
	public String readNullTerminatedAsciiString() {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        byte b = 1;
        while (b != 0) {
            b = readByte();
            baos.write(b);
        }
        byte[] buf = baos.toByteArray();
        char[] chrBuf = new char[buf.length];
        for (int x = 0; x < buf.length; x++) {
            chrBuf[x] = (char) buf[x];
        }
        return String.valueOf(chrBuf);
	}

	@Override
	public int getBytesRead() {
		return this.bs.getBytesRead();
	}

	@Override
	public int available() {
		return this.bs.available();
	}

	@Override
	public String readL1String() {
		int sLen = readByte();
		return readAsciiString(sLen);
	}

	@Override
	public String readL2String() {
		int sLen = readShort();
		return readAsciiString(sLen);
	}

	@Override
	public String readL4String() {
		int sLen = readInt();
		return readAsciiString(sLen);
	}
	
	public String readUnicodeString(int paramInt) {
		char[] ret = new char[paramInt];
        for (int x = 0; x < paramInt; x++) {
            ret[x] = readChar();
        }
        try {
            return String.valueOf(ret);
        } catch (Exception e) {
            System.err.println(e);
        }
        return "";
	}
	
	public String readL1WideString() {
		int sLen = readByte();
		return readUnicodeString(sLen);
	}
	public String readL2WideString() {
		int sLen = readShort();
		return readUnicodeString(sLen);
	}
	public String readL4WideString() {
		int sLen = readInt();
		return readUnicodeString(sLen);
	}
	
	public int seek(int Offset, SeekOrigin Origin) {
		return bs.seek(Offset, Origin);
	}
	
}
