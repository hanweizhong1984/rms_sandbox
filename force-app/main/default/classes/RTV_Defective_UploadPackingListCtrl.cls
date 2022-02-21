public with sharing class RTV_Defective_UploadPackingListCtrl {
    
    // 常量：商品的退残期限
    public static final Integer Expired_Month_Core = 24;  //常青款24个月
    public static final Integer Expired_Month_Seasonal = 18; //季节款18个月
    
    // 常量：不接受的退货理由关键字
    public static final String[] Unaccept_Reason_Words = new String[]{
        '鞋盒', '盒', '样品', '包装破损', '做工不良', '陈列', '陈列鞋', '眼扣损坏', '磨损', '脏污', '褪色', '退色'
    };

    //对应OrderId
    public final String orderId = ApexPages.currentPage().getParameters().get('id');
    private RTV_Order__c order = new RTV_Order__c();
    
    //文件名
    public String fileUploadName{get;set;}
    //文件内容跟
    public transient Blob fileUploadBody{get;set;}
    
    //新增Item和ItemPackingDetail
    private Map<String, RTV_Order_Item__c> newItems;
    private Map<String, RTV_Order_Packing__c> newPackings;
    private List<RTV_Order_Item_DEF_Detail__c> newDefDetails;
    
    //csv编码
    public List<ApexPages.SelectOption> fileCharsetOpts {get{return RMS_CSV_Iterator.CHARSET_OPTIONS;}}
    public String fileCharset = fileCharsetOpts.get(0).getValue();
    public String getFileCharset() {return fileCharset;}
    public void setFileCharset(String value) {this.fileCharset=value;}
    
    //csv必须有的标题列
    private static String[] Csv_Fields = new String[]{'货品号', '尺寸(美码)', '尺寸(亚码)', 'BU', '数量', '季节码', '零售价', '退货理由(必填)', '原残/客残', '箱号', '备注'};
    
    // 基础表：商品表
    private List<RMS_Product__c> productList;
    
    // 基础表：常青款
    private List<String> FTWCoreList;
    
    /** 基础表：tradingTerms */
    private transient Map<String, RMS_TradingTerm__c> tradingTerms;
    
    //OrderItem的RecordType集合
    Map<String, RecordType> allTypes = RMS_CommonUtil.getRecordTypes('RTV_Order_Item__c');

    /** 当前packinglist的：货品号集合 */
    private List<String> materialList;
    
    /** 当前packinglist的：货品号集合 */
    private Map<String,List<String>> usSizeMap;
    
    /** 当前packinglist的：箱号Map（key:箱号，value:BU） */
    private transient Map<String, String> boxCodeToBU;

    /** 上传是否有错误信息 */
    private Boolean isError = false;

    /** 特批商品的附件 */
    public SpecialDEF specialDef {get; set;}
    
    /** 返回包含错误信息的CSV上下文 */
    public Boolean isNeedErrorCsv {get; set;}
    public transient String resErrorCsv {get; set;}

    public String showMessage{get; set;}
    
    /**
     * 构造方法
     */
    public RTV_Defective_UploadPackingListCtrl() {
        this.order = [
            SELECT Id, Name, Order_Auth_Code__c, Sold_To__c, Ship_To__c,
                Ship_To__r.Name, 
                Sold_To__r.Name, 
                Sold_To__r.TT_APP_ACC__c, 
                Sold_To__r.TT_FTW_EG__c, 
                Sold_To__r.TT_FW_Seasonal__c ,
                Sold_To__r.Sold_To_Name_CN__c,
                Sold_To__r.SAP_Customer_Name__c
            FROM RTV_Order__c 
            WHERE ID = :this.orderId
        ];
        this.specialDef = new specialDef(this);
    }
    
    /**
     * 关闭页面
     */
    public Pagereference cancel()
    {
        PageReference returnPage = new PageReference('/' + this.orderId);
        returnPage.setRedirect(true);
        return returnPage;  
    }

    /**
     * 上传方法
     */
    public void uploadFile()
    {
        //初始化新增OrderItem
        this.materialList = new List<String>();
        this.boxCodeToBU = new Map<String,String>();
        this.tradingTerms = new Map<String, RMS_TradingTerm__c>();
        
        this.newItems = new Map<String, RTV_Order_Item__c>();
        this.newPackings = new Map<String, RTV_Order_Packing__c>();
        this.newDefDetails = new List<RTV_Order_Item_DEF_Detail__c>();
        this.isError = false;
        
        this.isNeedErrorCsv = false;
        this.resErrorCsv = '';
        
        //判断文件内容是否为空
        if(this.fileUploadBody == null) {
            RMS_CommonUtil.pageAddMessage(ApexPages.severity.ERROR, '请先选择上传文件！');
            this.showMessage='';
            return;
        }
        
        Savepoint savePot = Database.setSavepoint();
        try {
            // 上传
            this.doUpload();

            // 更新
            if(isError == false && !newItems.isEmpty()) {
                //新插入OrderItem前，删除原数据
                deleteOrderItem();
                
                // 新建
                insert this.newItems.values();
                insert this.newDefDetails;
                
                // 页面显示结果
                this.resErrorCsv = '';
                RMS_CommonUtil.pageAddMessage(ApexPages.severity.CONFIRM, '上传成功');
                this.showMessage='True';
            } 
            else if(isNeedErrorCsv){
                RMS_CommonUtil.pageAddMessage(ApexPages.severity.INFO, 'Packinglist上传失败！请参考返回的错误信息文件。');
                this.showMessage='';
            } 
            else {
                RMS_CommonUtil.pageAddMessage(ApexPages.severity.INFO, 'Packinglist上传失败！');
                this.showMessage='';
            }
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR, '上传失败！ '+ e.getMessage()));
            Database.rollback(savePot);
            this.showMessage='';
        }
    }
    
    /**
     * 获取csv数据
     */
    private void doUpload() {
        
        // 创建csv迭代器
        RMS_CSV_Iterator csvIter = new RMS_CSV_Iterator(this.fileUploadBody, this.fileCharset);
        csvIter.skipTitleLine(Csv_Fields);
        this.resErrorCsv += csvIter.headerLine + ',错误描述';

        // 先遍历一次csv，缩小product查询范围
        List<CsvOneLineForSort> csvTable = new List<CsvOneLineForSort>();
        while (csvIter.next()) {
            CsvOneLineForSort tr = new CsvOneLineForSort(csvIter);
            
            // 获取计算后的美码
            String bu2 = RMS_CommonUtil.item_getBu2(tr.get('BU'));
            String sizeUs = String.isBlank(tr.get('尺寸(美码)'))? RMS_CommonUtil.size_Asia2Us(tr.get('尺寸(亚码)'), bu2): tr.get('尺寸(美码)');
            tr.put('尺寸(美码)', sizeUs);
            
            // 记录csv行
            csvTable.add(tr);
            
            // 记录materialcode
            this.materialList.add(tr.get('货品号'));
        }
        csvTable.sort();
        
        //根据货品号查询对应商品
        //目的：缩小搜索范围，防止查询过多
        queryProduct(materialList);
        //检索UsSize范围
        queryUsSize();
        //检索TradingTerm
        queryTradingTerms();
        
        // 再遍历csv
        for (RMS_CSV_Iterator.OneLineInfo tr: csvTable) {
            this.resErrorCsv += '\r\n' + tr.line + ',';
            
            //检查SKU
            RMS_Product__c product = checkProduct(tr);
            // if (product == null) {
            //     continue;
            // }
            
            // 创建item
            newOrderItem(product,tr);
        }
    }
    
    /**
     * 检索商品信息
     */
    public void queryProduct(List<String> materialList) {
        // 检索商品表
        this.productList = [
            SELECT id,Name,Material_Code__c,Season_Code_CN__c,BU__c,MSRP__c,BUCN__c, Size_Range__c
            FROM RMS_Product__c 
            WHERE Material_Code__c IN :materialList
        ];
        
        // 检索常青款商品
        this.FTWCoreList = new List<String>();
        for (RMS_FTW_Core_List__c ftwCore: [
            SELECT id, Name
            FROM RMS_FTW_Core_List__c 
            WHERE Name IN :materialList
        ]) {
            this.FTWCoreList.add(ftwCore.Name.toUpperCase());
        }
    }
    
    /** 检索各个财年的TradingTerm */
    private void queryTradingTerms() {
        this.tradingTerms = new Map<String, RMS_TradingTerm__c>();
        
        for (RMS_TradingTerm__c tt: [
            SELECT TT_APP_ACC__c, TT_FW_Seasonal__c, TT_FTW_EG__c, Year__c, Name 
            FROM RMS_TradingTerm__c
            WHERE Sold_To_Code__c = :this.order.Sold_To__r.Name
        ]) {
            this.tradingTerms.put(tt.Name, tt);
        }
    }
    
    /**
     * 判断PackingList中商品是否在商品表中
     */
    public RMS_Product__c checkProduct(RMS_CSV_Iterator.OneLineInfo tr)
    {
        Boolean hasSimilarProduct = false;
        
        // 只需要匹配csv中BU的前2个字符
        String pBuSub = 
            tr.get('BU').startsWithIgnoreCase('AP') ? 'AP':
            tr.get('BU').startsWithIgnoreCase('AC') ? 'AC':
            tr.get('BU').startsWithIgnoreCase('F') ? 'F': '';
        
        // 遍历product
        for(RMS_Product__c product:productList){
            // 匹配Material和BU
            if(product.Material_Code__c.equals(tr.get('货品号'))
            && product.BUCN__c.startsWith(pBuSub)) {
                hasSimilarProduct = true;
                
                // 匹配到季节码时返回product
                if (product.Season_Code_CN__c!=null
                && product.Season_Code_CN__c.equalsIgnoreCase(tr.get('季节码'))) {
                    return product;
                }
            }
        }
        
        // 无法匹配Material和BU时
        if (hasSimilarProduct == false) {
            this.isError = true;
            this.isNeedErrorCsv = true;
            this.resErrorCsv += '该商品不存在！';
        }
        return null;
    }
    
    /**
     * 判断是否超过退货期限
     */
    public Boolean checkProductExpired(RMS_CSV_Iterator.OneLineInfo tr)
    {
        // 期限范围
        Integer expireMonth;
        if (this.FTWCoreList.contains(tr.get('货品号').toUpperCase())) {
            expireMonth = Expired_Month_Core;
        } else {
            expireMonth = Expired_Month_Seasonal;
        }
        
        String seasonCode = tr.get('季节码');
        //年
        Integer year = Integer.valueOf(seasonCode.substring(0, 2));
        //季度
        Integer quarter = Integer.valueOf(seasonCode.substring(3));
        
        //当前年份
        Integer yearToday = Date.today().year()-2000;
        //当前月份
        Integer monthToday = Date.today().month();

        if(yearToday > year)
        { 
            //第一季度
            if(quarter == 1 && (yearToday-year)*12+(monthToday-3) > expireMonth)
            {
                return false;
            }
            //第二季度
            if(quarter == 2 && (yearToday-year)*12+(monthToday-6) > expireMonth)
            {
                return false;
            }
            //第三季度
            if(quarter == 3 && (yearToday-year)*12+(monthToday-9) > expireMonth)
            {
                return false;
            }
            //第四季度
            if(quarter == 4 && (yearToday-year)*12+(monthToday-12) > expireMonth)
            {
                return false;
            }
        }

        return true;
    }
    /**
     * 新建Order Item
     */
    public void newOrderItem(RMS_Product__c product, RMS_CSV_Iterator.OneLineInfo tr)
    {
        // ----------------------------
        // 检查季节码
        // ----------------------------
        RMS_CommonUtil.SeasonCodeCN season;
        try { 
            season = new RMS_CommonUtil.SeasonCodeCN(tr.get('季节码'));
        } catch(Exception err) {
            isError = true;
            this.isNeedErrorCsv = true;
            this.resErrorCsv += '季节码格式错误! 请输入正确如: "20Q1"';
            return;
        }

        if(tr.get('BU') != null && tr.get('BU').startsWithIgnoreCase('F') 
        && (tr.get('尺寸(美码)').toUpperCase().contains('-')||tr.get('尺寸(亚码)').toUpperCase().contains('-'))){
            isError = true;
            this.isNeedErrorCsv = true;
            this.resErrorCsv += '尺码中半码不能用-来表示，例如4-请用4.5';
            return;
        }
        
        // ----------------------------
        // 添加item
        // ----------------------------
        RTV_Order_Item__c item = new RTV_Order_Item__c();
        item.RTV_Order__c = this.orderId;
        item.RecordTypeId = allTypes.get('Defective Order Item').id;
        
        // item.基础信息
        item.Material_Code__c = tr.get('货品号');
        item.Season_Code_CN__c = tr.get('季节码');
        item.BU_2__c = RMS_CommonUtil.item_getBu2(tr.get('BU'));
        item.SKU_Size_US__c = tr.get('尺寸(美码)').toUpperCase();
        item.SKU_Size_Asia__c = tr.get('尺寸(亚码)').toUpperCase();
        
        // ----------------------------
        // item.备注
        // ----------------------------
        item.Application_Remark__c = tr.get('备注');
        
        // item.备注: 无实物退残
        item.IsMaterial__c = RMS_CommonUtil.item_Def_IsNoDelivery(item.Application_Remark__c);
        
        // item.备注: 特批
        item.IsSpecialDEF__c = RMS_CommonUtil.item_Def_IsSepical(item.Application_Remark__c);
        if (item.IsSpecialDEF__c && this.specialDef.attachs.isEmpty()) {
            throw new RMS_CommonUtil.RMSException('请上传【特批】退残的证明文档.');
        }
        
        // ----------------------------
        // 检查退货期限 (特批时不检查)
        // ----------------------------
        if(item.IsSpecialDEF__c == false && checkProductExpired(tr) == false) {
            isError = true;
            this.isNeedErrorCsv = true;
            this.resErrorCsv += '对不起, 该商品已超过退货期限';
            return; 
        }
        
        // ----------------------
        // item.退货理由
        // ----------------------
        item.Defective_Reason__c = tr.get('退货理由(必填)');
        if (String.isBlank(item.Defective_Reason__c)) {
            isError = true;
            this.isNeedErrorCsv = true;
            this.resErrorCsv += '请填写退货理由';
            return;
        }
        // 检查退货理由的敏感词  (特批时不检查)
        if (item.IsSpecialDEF__c == false) {
            for (String word: Unaccept_Reason_Words) {
                if (item.Defective_Reason__c.contains(word)) {
                    isError = true;
                    this.isNeedErrorCsv = true;
                    this.resErrorCsv += '退残申请中出现不可接受的退货原因，拒绝提交申请';
                    return;
                }
            }
        }
        
        // ----------------------
        // item.product信息
        // ----------------------
        if (product != null) {
            // item.product
            item.Product__c = product.Id;
            item.SKU_BU__c = product.BUCN__c;
            item.MSRP__c = product.MSRP__c;
            
            // item.tradingTerm
            Boolean isFwCore = this.FTWCoreList.contains(tr.get('货品号').toUpperCase());
            RMS_TradingTerm__c tradeTermObj = this.tradingTerms.get(order.Sold_To__r.Name + season.fiscalYear);
            if (tradeTermObj == null) {
                this.isError = true;
                this.isNeedErrorCsv = true;
                this.resErrorCsv += '缺少该SoldTo的[TradingTerm]基础数据（财年='+season.fiscalYear+'）';
                return;
            }
            item.TradeTerm__c = RMS_CommonUtil.item_getTradeTerm_DEF(product.BUCN__c, tradeTermObj, isFwCore);
            if (item.TradeTerm__c == null) {
                this.isError = true;
                this.isNeedErrorCsv = true;
                this.resErrorCsv += '该SoldTo的[TradingTerm]为空白（财年='+season.fiscalYear+'）';
                return;
            }
            
            // item.申请金额
            item.NET__c = RMS_CommonUtil.item_getNet(product, item.TradeTerm__c);
        }
        
        // ----------------------
        // 检查尺码
        // ----------------------
        // 美码没有填写时，使用亚码计算美码
        if (String.isBlank(item.SKU_Size_US__c)) {
            item.SKU_Size_US__c = RMS_CommonUtil.size_Asia2Us(item.SKU_Size_Asia__c, item.BU_2__c);
        } 
        // 亚码没有填写时，使用美码计算亚码
        else if (String.isBlank(item.SKU_Size_Asia__c)) {
            item.SKU_Size_Asia__c = RMS_CommonUtil.size_Asia2Us(item.SKU_Size_US__c, item.BU_2__c);
        }
        // 检查美码范围
        if(this.usSizeMap.containsKey(item.BU_2__c)) {
            if(!this.usSizeMap.get(item.BU_2__c).contains(item.SKU_Size_US__c)) {
                isError = true;
                String okSizeRange = (product == null || product.Size_Range__c == null)? '': ', 正确的美码范围:' + product.Size_Range__c.replace('-', '~');
                this.isNeedErrorCsv = true;
                this.resErrorCsv += '美码尺寸错误！' + okSizeRange;
                return;
            }
        }
        
        // >>>>> DEF Packinglist 中箱号不是必填项目，也不检查填写内容 >>>>>>>
        // // ----------------------
        // // 检查 AC/AP 和 FW 不能混装
        // // ----------------------
        // if(boxCodeToBU.containsKey(tr.get('箱号')+order.name)) {
        //     if(boxCodeToBU.get(tr.get('箱号')+order.name) != item.BU_2__c.substring(0, 1)) {
        //         isError = true;
        //         RMS_CommonUtil.pageAddMessage(ApexPages.severity.WARNING, '[行'+tr.lineIndex+'] 不同BU存在混箱包装，必须拆箱！'
        //             + ', BU=' + tr.get('BU')
        //             + ', 箱号=' + tr.get('箱号')
        //         );
        //         return;
        //     }     
        // } else {
        //     boxCodeToBU.put(tr.get('箱号')+order.name, item.BU_2__c.substring(0, 1));
        // }
        // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
        
        // item.箱号
        item.Defective_Box_Code__c = tr.get('箱号');
        
        // item.数量
        item.Application_QTY__c = Double.valueOf(tr.get('数量'));
        
        // item.原残/客残
        item.Defective_Source__c = tr.get('原残/客残');
        
        // item.名称和唯一键
        Integer numFrom = this.newDefDetails.Size() + 1;
        Integer numTill = this.newDefDetails.Size() + Integer.valueOf(item.Application_QTY__c);
        item.Name = RMS_CommonUtil.item_getName(item);
        item.UniqueKey__c = RMS_CommonUtil.item_getUniqueKeyDef(order.Order_Auth_Code__c, item, numFrom, numTill);
        
        // 添加到待新增
        this.newItems.put(item.UniqueKey__c, item);
        
        // 添加item.packingDetail
        newItemDefDetail(item, tr);
    }
    
    /** 添加item.DefDetail */
    private void newItemDefDetail(RTV_Order_Item__c item, RMS_CSV_Iterator.OneLineInfo tr) {
        // 将 item 拆成 qty=1 的 detail
        for (Integer idx = 0; idx < tr.getDecimal('数量', 0); idx++) {
            
            // 创建 detail
            RTV_Order_Item_DEF_Detail__c def = new RTV_Order_Item_DEF_Detail__c();
            def.Application_QTY__c = 1;
            
            // '退残理由'
            def.Defective_Reason__c = item.Defective_Reason__c;
            
            // 唯一信息
            def.RTV_Order_Item__r = new RTV_Order_Item__c(UniqueKey__c= item.UniqueKey__c);
            def.Detail_Number__c = this.newDefDetails.Size() + 1;
            def.Name = def.Detail_Number__c.format();

            //packing detail
            def.Order_Auth_Code__c = this.order.Order_Auth_Code__c+item.BU_2__c;
            def.BU_2__c = item.BU_2__c;
            def.Customer_Abbreviation__c = this.order.Sold_To__r.Sold_To_Name_CN__c;
            def.Customer_Name__c = this.order.Sold_To__r.Sold_To_Name_CN__c;
            def.Defective_Source__c = item.defective_Source__c;

            //SKU Detail
            def.Material_Code__c = item.Material_Code__c;
            def.SKU_Size_US__c = item.SKU_Size_US__c;
            def.Sold_To__c = this.order.Sold_To__c;
            def.Ship_To__c = this.order.Ship_To__c;
            def.Season_Code_CN__c = item.Season_Code_CN__c;
            
            // 保存到待新增
            this.newDefDetails.add(def);
        }
    }
    
    /**
     * 清空现Order下的OrderItem
     */
    public void deleteOrderItem()
    {
        List<RTV_Order_Item__c> orderItemList =[SELECT ID FROM RTV_Order_Item__c WHERE RTV_Order__c =:this.orderId];
        if(orderItemList.size()>0) {
            delete orderItemList;
        }
    }
    /**
     * 获取US Size数据
     */
    public void queryUsSize()
    {
        usSizeMap = new Map<String,List<String>>();
        for(RMS_US_Size__c usSize:[SELECT BU__c,Size__c FROM RMS_US_Size__c])
        {
            if(usSizeMap.containsKey(usSize.BU__c))
            {
                usSizeMap.get(usSize.BU__c).add(usSize.Size__c);
            }
            else {
                List<String> size = new List<String>();
                size.add(usSize.Size__c);
                usSizeMap.put(usSize.BU__c, size);
            }
        }
    }
    
    /** 特批退残 */
    public class SpecialDEF {
        public RTV_Defective_UploadPackingListCtrl ctrl;
        public List<Attachment> attachs {get; set;}
        
        public transient Blob inputFileBody {get; set;}
        public transient String inputFileName {get; set;}
        
        /** 构造 */
        public SpecialDEF(RTV_Defective_UploadPackingListCtrl ctrl) {
            this.ctrl = ctrl;
            queryExistFile();
        }
        /** 查询附件 */
        public void queryExistFile() {
            this.attachs = [
                SELECT Id, Name, CreatedBy.Name FROM Attachment 
                WHERE ParentId = :this.ctrl.orderId AND Name LIKE '[特批证明]%'
            ];
        }
        /** 上传附件 */
        public void uploadFile() {
            //检查附件
            if (this.inputFileBody == null) {
                RMS_CommonUtil.pageAddMessage(ApexPages.Severity.ERROR, '请上传【特批】退残的证明文档.');
                return;
            }
            //创建附件
            try {
                Attachment attach = new Attachment();
                attach.Parentid = this.ctrl.order.Id;
                attach.Body = this.inputFileBody;
                attach.Name = '[特批证明] '+ this.inputFileName;
                attach.Description = '## 特批退残证明文档 ##';
                insert attach;
                queryExistFile();
            } 
            catch(DmlException err) {
                RMS_CommonUtil.pageAddMessage(ApexPages.Severity.ERROR, err.getDmlMessage(0));
            }
        }
        /** 删除附件 */
        public void deleteFile() {
            Id attachId= Apexpages.currentPage().getParameters().get('attachId');
            try {
                Attachment attach = new Attachment();
                attach.Id = attachId;
                delete attach;
                queryExistFile();
            } 
            catch(DmlException err) {
                RMS_CommonUtil.pageAddMessage(ApexPages.Severity.ERROR, err.getDmlMessage(0));
            }
        }
    }
    
    /** 继承OneLineInfo对象，并添加排序条件 */
    class CsvOneLineForSort extends RMS_CSV_Iterator.OneLineInfo implements Comparable{
        /** 构造方法 */
        public CsvOneLineForSort(RMS_CSV_Iterator iter) {
            super(iter);
        }
        /** 实装接口: Comparable.compareTo() */
        public Integer compareTo(Object compareTo) {
            CsvOneLineForSort comp = (CsvOneLineForSort)compareTo;
            
            // 比较'BU'的大小，顺序='FW'>'AP'>'AC'
            Integer compare_BU = compareByCustomSort(
                this.get('BU'), 
                comp.get('BU'), 
                new String[]{'FW', 'AP', 'AC'});
            
            // 比较'MaterialCode'的大小
            Integer compare_Material = 
                this.get('货品号') > comp.get('货品号') ? 1 : 
                this.get('货品号') < comp.get('货品号') ? -1 : 0;
            
            // 比较'Size'大小
            Integer compare_Size = 
                this.get('尺寸(美码)') > comp.get('尺寸(美码)') ? 1 : 
                this.get('尺寸(美码)') < comp.get('尺寸(美码)') ? -1 : 0;
            
            // 比较结果优先级为: BU > MaterialCode > Size
            return compare_BU != 0? compare_BU:
                compare_Material != 0? compare_Material:
                compare_Size != 0? compare_Size: 0;
        }
        /** 按照指定顺序比较两个Str的大小关系 (Str只匹配startsWith) */
        private Integer compareByCustomSort(String thisStr, String compStr, List<String> strSort) {
            Integer thisIdx = -1;
            Integer compIdx = -1;
            Integer i = 0;
            for (String str: strSort) {
                i ++;
                if (thisStr.startsWith(str)) { thisIdx = i; }
                if (compStr.startsWith(str)) { compIdx = i; }
            }
            return thisIdx > compIdx ? 1: thisIdx < compIdx ? -1: 0;
        }
    }
}