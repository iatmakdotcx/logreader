package mak.data.input;

public abstract interface LittleEndianAccessor
{
  /**
   * ��ȡһ���ֽ�
   * @return
   */
  public abstract byte readByte();
  
  public abstract char readChar();

  public abstract short readShort();

  public abstract int readInt();

  public abstract long readLong();
  /**
   * ����ָ���ֽ�
   * @param paramInt
   */
  public abstract void skip(int paramInt);
  /**
   * ��ȡָ������������
   * @param Ҫ��ȡ���ֽ���
   * @return
   */
  public abstract byte[] read(int paramInt);
 
  public abstract float readFloat();

  public abstract double readDouble();
  
  public abstract String readAsciiString(int paramInt);

  public abstract String readNullTerminatedAsciiString();
  /**
   * ��ȡһ������1λ����ͷ���ַ���
   *
   */
  public abstract String readL1String();
  /**
   * ��ȡһ������2λ����ͷ���ַ���
   *
   */
  public abstract String readL2String();
  /**
   * ��ȡһ������4λ����ͷ���ַ���
   *
   */
  public abstract String readL4String();
  /**
   * ��ȡ�Ѷ�ȡ���ֽ���
   * @return
   */
  public abstract int getBytesRead();
  /**
   * ��ȡ�ɶ�ȡ���ֽ���
   * @return
   */
  public abstract int available();
}