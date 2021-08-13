/** DTC>DEF>上传退残理由 */
public with sharing class RTV_DTC_DEF_Upload_Reason {
    /** 参数：orderId */
    public final String orderId = ApexPages.currentPage().getParameters().get('orderId');
    
    /** csv文件 */
    public String fileUploadName{get;set;}
    public transient Blob fileUploadBody{get;set;}
    
    /** csv编码 */
    public List<ApexPages.SelectOption> fileCharsetOpts {get{return RMS_CSV_Iterator.CHARSET_OPTIONS;}}
    public String fileCharset = fileCharsetOpts.get(0).getValue();
    public String getFileCharset() {return fileCharset;}
    public void setFileCharset(String value) {this.fileCharset=value;}
    
    /** csv必须列标题 */
    private static String[] Csv_Fields = new String[]{'授权码', '序号', 'POS SKU', '货品号', '尺寸(美码)', '退货理由(必填)', '原残/客残', '备注'};
    
    /** 现有的item */
    private Map<String, RTV_Order_Item_DEF_Detail__c> existDefDetails;
    
    /** 更新的item */
    private Map<Id, RTV_Order_Item__c> updItems;
    private List<RTV_Order_Item_DEF_Detail__c> updDefDetails;
    
    /** 返回包含错误信息的CSV上下文 */
    public Boolean isNeedErrorCsv {get; set;}
    public transient String resErrorCsv {get; set;}
    
    /** 特批商品的附件 */
    public SpecialDEF specialDef {get; set;}
    
    /** 常量：不接受的退货理由关键字 */
    public static final String[] Unaccept_Reason_Words = new String[]{
        '鞋盒', '盒', '样品', '包装破损', '做工不良', '陈列', '陈列鞋', '眼扣损坏', '磨损', '脏污', '褪色', '退色'
    };
    
    /**
     * 构造方法
     */
    public RTV_DTC_DEF_Upload_Reason() {
        this.specialDef = new SpecialDef(this);
    }
    
    /**
     * 关闭页面
     */
    public Pagereference cancel() {
        PageReference returnPage = new PageReference('/' + this.orderId);
        returnPage.setRedirect(true);
        return returnPage;  
    }
    
    /**
     * 上传方法
     */
    public void upload() {
        // 初期化
        this.existDefDetails = new Map<String, RTV_Order_Item_DEF_Detail__c>();
        this.updItems = new Map<Id, RTV_Order_Item__c>();
        this.updDefDetails = new List<RTV_Order_Item_DEF_Detail__c>();
        this.isNeedErrorCsv = false;
        this.resErrorCsv = '';
        
        // 判断文件内容是否为空
        if(this.fileUploadBody == null) {
            RMS_CommonUtil.pageAddMessage(ApexPages.severity.ERROR, '请先选择上传文件！');
            return;
        }
        
        // 检索现有记录
        this.queryItems();
        
        // 上传
        Savepoint savePot = Database.setSavepoint();
        try {
            this.doUpload();

            // 更新
            if(isNeedErrorCsv == false && !this.updItems.isEmpty() && !this.updDefDetails.isEmpty()) {
                update this.updItems.values();
                update this.updDefDetails;
                
                // 页面显示结果
                this.resErrorCsv = '';
                RMS_CommonUtil.pageAddMessage(ApexPages.severity.CONFIRM, '上传成功');
            } 
            else if(isNeedErrorCsv){
                RMS_CommonUtil.pageAddMessage(ApexPages.severity.INFO, 'Packinglist上传失败！请参考返回的错误信息文件。');
            }
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR, '上传失败！ '+ e.getMessage()));
            Database.rollback(savePot);
        }
    }
    
    /** 检索现存的item */
    private void queryItems() {
        for (RTV_Order_Item_DEF_Detail__c detail: [
            SELECT Id, Detail_Number__c, Defective_Reason__c, Defective_Source__c,
                RTV_Order_Item__r.Id,
                RTV_Order_Item__r.Defective_Reason__c,
                RTV_Order_Item__r.Defective_Source__c,
                RTV_Order_Item__r.RTV_Order__r.Name
            FROM RTV_Order_Item_DEF_Detail__c
            WHERE RTV_Order_Item__r.RTV_Order__c = :this.orderId
        ]) {
            String key = 
                '##order=' + detail.RTV_Order_Item__r.RTV_Order__r.Name + 
                '##number=' + detail.Detail_Number__c;
            this.existDefDetails.put(key, detail);
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
        
        // 遍历csv
        while (csvIter.next()) {
            RMS_CSV_Iterator.OneLineInfo tr = new RMS_CSV_Iterator.OneLineInfo(csvIter);
            this.resErrorCsv += '\r\n' + tr.line + ',';
            
            // 获取现有的detail
            String key = 
                '##order=' + tr.get('授权码') + 
                '##number=' + tr.get('序号');
            RTV_Order_Item_DEF_Detail__c detail = this.existDefDetails.get(key);
            
            // 没有对应detail时
            if (detail == null) {
                this.isNeedErrorCsv = true;
                this.resErrorCsv += '无法找到该[授权码]和[序号]对应的记录';
                continue;
            }
            
            // 更新item
            if (updItem(detail, tr) == null) {
                continue;
            }
            // 更新detail
            updDetail(detail, tr);
        }
    }
    
    /**
     * 更新item
     */
    public RTV_Order_Item__c updItem(RTV_Order_Item_Def_Detail__c detail, RMS_CSV_Iterator.OneLineInfo tr) {
        RTV_Order_Item__c updItem = new RTV_Order_Item__c();
        updItem.Id = detail.RTV_Order_Item__c;
        
        // item.货品号
        updItem.Material_Code__c = tr.get('货品号');
        updItem.SKU_Size_US__c = tr.get('尺寸(美码)');
        
        // item.备注：无实物退残
        updItem.Application_Remark__c = tr.get('备注');
        updItem.IsMaterial__c = RMS_CommonUtil.item_Def_IsNoDelivery(updItem.Application_Remark__c);
        
        // item.备注: 特批
        updItem.IsSpecialDEF__c = RMS_CommonUtil.item_Def_IsSepical(updItem.Application_Remark__c);
        if (updItem.IsSpecialDEF__c && this.specialDef.attachs.isEmpty()) {
            throw new RMS_CommonUtil.RMSException('请上传【特批】退残的证明文档.');
        }
        
        // item.退货理由
        updItem.Defective_Reason__c = tr.get('退货理由(必填)');
        updItem.Defective_Source__c = tr.get('原残/客残');
        
        // 检查退货理由
        if (String.isBlank(updItem.Defective_Reason__c)) {
            this.isNeedErrorCsv = true;
            this.resErrorCsv += '请填写退货理由';
            return null;
        }
        // 检查退货理由的敏感词  (特批时不检查)
        if (updItem.IsSpecialDEF__c == false) {
            for (String word: Unaccept_Reason_Words) {
                if (updItem.Defective_Reason__c.contains(word)) {
                    this.isNeedErrorCsv = true;
                    this.resErrorCsv += '退残申请中出现不可接受的退货原因，拒绝提交申请';
                    return null;
                }
            }
        }
        
        // 添加到待更新
        if (updItems.containsKey(updItem.Id) == false) {
            this.updItems.put(updItem.Id, updItem);
        }
        return updItem;
    }
    
    /**
     * 更新detail
     */
    public void updDetail(RTV_Order_Item_Def_Detail__c detail, RMS_CSV_Iterator.OneLineInfo tr) {
        RTV_Order_Item_DEF_Detail__c updDetail = new RTV_Order_Item_DEF_Detail__c();
        updDetail.Id = detail.Id;
        updDetail.Defective_Reason__c = tr.get('退货理由(必填)');
        updDetail.Defective_Source__c = tr.get('原残/客残');
        this.updDefDetails.add(updDetail);
    }
    
    /**
     * 上传特批退残证明的Form
     */
    public class SpecialDEF {
        public RTV_DTC_DEF_Upload_Reason ctrl;
        public List<Attachment> attachs {get; set;}
        
        public transient Blob inputFileBody {get; set;}
        public transient String inputFileName {get; set;}
        
        /** 构造 */
        public SpecialDEF(RTV_DTC_DEF_Upload_Reason ctrl) {
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
                attach.Parentid = this.ctrl.orderId;
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
}