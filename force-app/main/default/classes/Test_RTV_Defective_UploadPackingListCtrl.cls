@IsTest(isParallel=true)
public with sharing class Test_RTV_Defective_UploadPackingListCtrl {
    @IsTest
    private static void test()
    {
        // 数据 soldto ~ shipto
        RMS_Account_Group__c acgroup = new RMS_Account_Group__c();
        insert acgroup;
        
        RMS_Sold_To__c soldto = new RMS_Sold_To__c();
        soldTo.Name = 'xxxx';
        soldto.Account_Group__c = acgroup.Id;
        soldTo.TT_APP_ACC__c = 1.2;
        soldTo.TT_FW_Seasonal__c = 1.2;
        soldTo.TT_FTW_EG__c = 1.2;
        insert soldto;
        
        RMS_Ship_To__c shipto = new RMS_Ship_To__c();
        shipto.Name = '100001';
        shipto.Sold_To_Code__c = soldto.Id;
        insert shipto;
        
        // 数据 order
        RTV_Order__c order = new RTV_Order__c();
        order.Sold_To__c = soldto.Id;
        order.Ship_To__c = shipto.Id;
        insert order;
        
        // 数据 product
        RMS_Product__c product = new RMS_Product__c();
        product.Material_Code__c = '[material]';
        product.Season_Code_CN__c = '21Q1';
        product.BU__c = 'APP';
        product.BUCN__c = 'APP';
        product.MSRP__c = 123.45;
        insert product;
        
        RMS_FTW_Core_List__c ftwCore = new RMS_FTW_Core_List__c();
        ftwCore.Name = product.Name;
        insert ftwCore;
        
        // masterdata.tradingterm
        RMS_TradingTerm__c tradeTerm = new RMS_TradingTerm__c();
        tradeTerm.Name = soldto.Name+'2021';
        tradeTerm.TT_APP_ACC__c = 0.9;
        tradeTerm.TT_FTW_EG__c = 0.9;
        tradeTerm.TT_FW_Seasonal__c = 0.9;
        tradeTerm.Year__c = 2021;
        insert tradeTerm;
        
        // 测试controller
        Apexpages.currentPage().getParameters().put('id',order.id);
        RTV_Defective_UploadPackingListCtrl ctrl = new RTV_Defective_UploadPackingListCtrl();
        
        // 空
        ctrl.uploadFile();
        
        // 新增item
        ctrl.fileUploadName = 'xxxx';
        ctrl.getFileCharset();
        ctrl.setFileCharset('UTF-8');
        
        
        // 错误
        ctrl.fileUploadBody = Blob.valueof(
            '\r' +
            '箱号,货品号,尺寸(美码),尺寸(亚码),BU,季节码,数量,零售价,退货理由(必填),原残/客残,备注\r' + 
            '[box],[material],6,,AP,21Q1,2,599,[退货理由],原残,特批\r'
        );
        ctrl.uploadFile();
        
        // 错误
        ctrl.fileUploadBody = Blob.valueof(
            '\r' +
            '箱号,货品号,尺寸(美码),尺寸(亚码),BU,季节码,数量,零售价,退货理由(必填),原残/客残,备注\r' + 
            '[box],[material],6,,AP,xxxQxx,2,599,[退货理由],原残,\r' +
            '[box],[material],6,,AP,21Q1,2,599,,原残,\r' +
            '[box],[material],6,,FW,21Q1,1,599,[退货理由],原残,\r' +
            '[box],[material],6,,AP,21Q1,1,599,,原残,\r' +
            '[box],[material],6,,AP,21Q1,1,599,鞋盒,原残,\r' +
            '[box],错误,7,AP,21Q1,1,469,[退货理由],原残,\r'
        );
        ctrl.uploadFile();
        
        // 正确
        ctrl.fileUploadBody = Blob.valueof(
            '\r' +
            '箱号,货品号,尺寸(美码),尺寸(亚码),BU,季节码,数量,零售价,退货理由(必填),原残/客残,备注\r' + 
            '[box],[material],6,,AP,21Q1,2,599,[退货理由],原残,\r' +
            '[box],[material],6,,AP,21Q1,1,599,[退货理由],原残,\r'
        );
        ctrl.uploadFile();
        
        // 关闭
        ctrl.cancel();
        
        // -----------------------
        // 上传特批附件
        // -----------------------
        ctrl.specialDef.inputFileBody = Blob.valueOf('xx');
        ctrl.specialDef.inputFileName = 'xx.txt';
        try { ctrl.specialDef.uploadFile(); }catch(Exception err){}
        try { ctrl.specialDef.deleteFile(); }catch(Exception err){}
    }
}