package mak.capture.log;

import java.awt.Color;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Date;

import javax.swing.text.BadLocationException;
import javax.swing.text.DefaultStyledDocument;
import javax.swing.text.SimpleAttributeSet;
import javax.swing.text.StyleConstants;

import mak.ui.Frm_Main;

public class MainWndOutput implements Output {
    private DefaultStyledDocument defaultStyledDocument;
    private final Color Info_Text = new Color(0, 0, 0);
    private final Color Warning_Text = new Color(0, 0, 255);
    private final Color Err_Text = new Color(255, 0, 0);
    private final DateFormat format = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
    private static MainWndOutput instance = new MainWndOutput();

    public static MainWndOutput getInstance() {
        return instance;
    }

    MainWndOutput() {
        Frm_Main ff = Frm_Main.getInstance();
        defaultStyledDocument = (DefaultStyledDocument) ff.logwnd.getDocument();
    }

    public String getTimeString() {
        Date date = new Date();
        return format.format(date) + "  :  ";
    }

    @Override
    public void Info(String var1) {
        SimpleAttributeSet simpleAttributeSet = new SimpleAttributeSet();
        StyleConstants.setForeground(simpleAttributeSet, this.Info_Text);
        try {
            defaultStyledDocument.insertString(defaultStyledDocument.getLength(), getTimeString() + var1 + "\n", simpleAttributeSet);
        } catch (BadLocationException e) {
            e.printStackTrace();
        }
    }

    @Override
    public void Warning(String var1) {
        SimpleAttributeSet simpleAttributeSet = new SimpleAttributeSet();
        StyleConstants.setForeground(simpleAttributeSet, this.Warning_Text);
        try {
            defaultStyledDocument.insertString(defaultStyledDocument.getLength(), getTimeString() + var1 + "\n", simpleAttributeSet);
        } catch (BadLocationException e) {
            e.printStackTrace();
        }
    }

    @Override
    public void Error(String var1) {
        SimpleAttributeSet simpleAttributeSet = new SimpleAttributeSet();
        StyleConstants.setForeground(simpleAttributeSet, this.Err_Text);
        try {
            defaultStyledDocument.insertString(defaultStyledDocument.getLength(), getTimeString() + var1 + "\n", simpleAttributeSet);
        } catch (BadLocationException e) {
            e.printStackTrace();
        }
    }

}
