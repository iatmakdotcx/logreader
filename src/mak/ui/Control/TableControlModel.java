/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package mak.ui.Control;

import javax.swing.table.DefaultTableModel;

/**
 *
 * @author Chin
 */
public class TableControlModel extends DefaultTableModel {
     

    public Class<?> getColumnClass(int columnIdx){
        return Object.class;        
    }
    
    @Override
    public Object getValueAt(int rowIndex, int columnIndex){
        
        return null;
    }
    
}
