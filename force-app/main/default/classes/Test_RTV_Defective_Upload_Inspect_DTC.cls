@IsTest(isParallel=true)
public class Test_RTV_Defective_Upload_Inspect_DTC {
    @isTest
    public static void test() {
        // masterdata.soldto
        RMS_Sold_To__c soldto = new RMS_Sold_To__c();
        soldto.Name = 'xxx';
        insert soldto;
        
        // masterdata.tradingterm
        RMS_TradingTerm__c tradeTerm = new RMS_TradingTerm__c();
        tradeTerm.Name = soldto.Name+'2021';
        tradeTerm.TT_APP_ACC__c = 0.9;
        tradeTerm.TT_FTW_EG__c = 0.9;
        tradeTerm.TT_FW_Seasonal__c = 0.9;
        tradeTerm.Year__c = 2021;
        insert tradeTerm;
        
        RMS_Product__c product = new RMS_Product__c();
        product.Material_Code__c = '[material]';
        product.BUCN__c = 'APP';
        product.Season_Code_CN__c = '21Q1';
        product.SKU__c = '[material]00';
        insert product;
        
        // defSummary
        RTV_DEF_Summary__c summary = new RTV_DEF_Summary__c();
        summary.Year__c = '2021';
        summary.Month__c = 3;
        insert summary;
        
        // order
        RTV_Order__c order = new RTV_Order__c();
        order.RTV_DEF_Summary__c = summary.Id;
        order.Name = '[Order1]';
        order.Order_Auth_Code__c = order.Name;
        order.Status__c = 'Delivered';
        order.Sold_To__c = soldto.Id;
        insert order;
        
        // item
        RTV_Order_Item__c item = new RTV_Order_Item__c();
        item.RTV_Order__c = order.Id;
        item.Name = 'xxx';
        item.Material_Code__c = '[material]';
        item.BU_2__c = 'AP';
        item.Season_Code_CN__c = '21Q1';
        item.SKU_Size_US__c = 'XL';
        item.POS_SKU__c = product.SKU__c+item.SKU_Size_US__c;
        insert item;
        
        // detail
        RTV_Order_Item_DEF_Detail__c detail = new RTV_Order_Item_DEF_Detail__c();
        detail.RTV_Order_Item__c = item.Id;
        detail.Detail_Number__c = 1;
        insert detail;
        
        // -------------------------
        // 开始测试
        // -------------------------
        ApexPages.currentPage().getParameters().put('defSummaryId', summary.Id);
        RTV_Defective_Upload_Inspect_DTC ctrl = new RTV_Defective_Upload_Inspect_DTC();
        ctrl.fileUploadName = 'xxxx';
        ctrl.getFileCharset();
        ctrl.setFileCharset('UTF-8');
        ctrl.upload();
        
        // 错误
        ctrl.createItemIfNotFound = false;
        ctrl.fileUploadBody = Blob.valueof('\r'
            +'Bar Code,类别,客户简称,soldto,shipto,客户全称,退残编号,序号,MATERIAL,Style,Color,尺码,季节码,申请数量,退货理由（申请人）,客/原残（申请人）,退货理由（LF）,客/原残（LF）,工厂代码,实收数量,可接受退货数量,specialcase退CC,>12M<18M,拒收件数,拒收原因,箱号,代码,备注\r'
            +'Bar Code,AP,[客户简称],[soldto],[shipto],[客户全称],[order错误],1,[material],Style,Color,XL,21Q1,1,[退货理由申请人],[客/原残申请人],[退货理由LF],[客/原残LF],[工厂代码],1,1,,,0,[拒收原因],[box],[code],特批\r'
            +'Bar Code,AP,[客户简称],[soldto],[shipto],[客户全称],[Order1]AP,1,[product错误],Style,Color,XL,21Q1,1,[退货理由申请人],[客/原残申请人],[退货理由LF],[客/原残LF],[工厂代码],1,1,,,0,[拒收原因],[box],[code],特批\r'
            +'Bar Code,AP,[客户简称],[soldto],[shipto],[客户全称],[Order1]AP,1,[material],Style,Color,XL,季节码错误,1,[退货理由申请人],[客/原残申请人],[退货理由LF],[客/原残LF],[工厂代码],1,1,,,0,[拒收原因],[box],[code],特批\r'
            +'Bar Code,AP,[客户简称],[soldto],[shipto],[客户全称],[Order1]AP,1,[material],,Color,XL,季节码错误,1,[退货理由申请人],[客/原残申请人],[退货理由LF],[客/原残LF],[工厂代码],1,1,,,0,[拒收原因],[box],[code],特批\r'
            +'Bar Code,AP,[客户简称],[soldto],[shipto],[客户全称],[Order1]AP,1,[material],Style,,XL,季节码错误,1,[退货理由申请人],[客/原残申请人],[退货理由LF],[客/原残LF],[工厂代码],1,1,,,0,[拒收原因],[box],[code],特批\r'
        );
        ctrl.upload();
        
        // 新增记录错误
        ctrl.createItemIfNotFound = false;
        ctrl.fileUploadBody = Blob.valueof('\r'
            +'Bar Code,类别,客户简称,soldto,shipto,客户全称,退残编号,序号,MATERIAL,Style,Color,尺码,季节码,申请数量,退货理由（申请人）,客/原残（申请人）,退货理由（LF）,客/原残（LF）,工厂代码,实收数量,可接受退货数量,specialcase退CC,>12M<18M,拒收件数,拒收原因,箱号,代码,备注\r'
            +'Bar Code,AP,[客户简称],[soldto],[shipto],[客户全称],[Order1]AP,2,[material],Style,Color,XL,21Q1,1,创建新item,,[客/原残LF],[工厂代码],1,1,,,0,[拒收原因],[box],[code],特批\r'
            +'Bar Code,AP,[客户简称],[soldto],[shipto],[客户全称],[Order1]AP,3,[material],Style,Color,XL,21Q1,1,创建新item,[客/原残申请人],[退货理由LF],[客/原残LF],[工厂代码],1,1,,,0,[拒收原因],[box],[code],特批\r'
        );
        ctrl.upload();
        
        // 正确
        ctrl.createItemIfNotFound = true;
        ctrl.fileUploadBody = Blob.valueof('\r'
            +'Bar Code,类别,客户简称,soldto,shipto,客户全称,退残编号,序号,MATERIAL,Style,Color,尺码,季节码,申请数量,退货理由（申请人）,客/原残（申请人）,退货理由（LF）,客/原残（LF）,工厂代码,实收数量,可接受退货数量,specialcase退CC,>12M<18M,拒收件数,拒收原因,箱号,代码,备注\r'
            +'Bar Code,AP,[客户简称],[soldto],[shipto],[客户全称],[Order1]AP,1,[material],Style,Color,XL,21Q1,1,[退货理由申请人],[客/原残申请人],[退货理由LF],[客/原残LF],[工厂代码],1,1,,,0,[拒收原因],[box],[code],特批\r'
            +'Bar Code,AP,[客户简称],[soldto],[shipto],[客户全称],[Order1]AP,2,[material],Style,Color,XL,21Q1,1,创建新item,[客/原残申请人],[退货理由LF],[客/原残LF],[工厂代码],1,1,,,0,[拒收原因],[box],[code],特批\r'
        );
        ctrl.upload();
        
        ctrl.upload();
        
        ctrl.cancel();
    }
}