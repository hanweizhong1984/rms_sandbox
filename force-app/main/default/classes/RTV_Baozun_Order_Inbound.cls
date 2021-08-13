public with sharing class RTV_Baozun_Order_Inbound {
    //order id
    public final String orderId = ApexPages.currentPage().getParameters().get('id');
    //order
    public RTV_Order__c order{get; set;}
    //控制inbound按钮
    public Boolean isInbound{get; set;}

    //文件内容
    public transient Blob fileBody{get;set;}
    //文件名
    public String fileName{get;set;}

    //附件
    private Attachment attach;

    public RTV_Baozun_Order_Inbound()
    {
        this.order = [SELECT ID,Name,Application_QTY__c,RTV_Baozun_Seeding__r.Name FROM RTV_Order__c WHERE ID =:this.orderId];

        this.isInbound = true;
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
     * 入库方法
     */
    public void inbound()
    {
        RTV_Order__c newOrder = new RTV_Order__c();
        newOrder.id = this.orderId;
        newOrder.Status__c = 'Inbound';
        newOrder.Seeding_Status__c = 'Inbound';
        update newOrder;

        this.isInbound = false;

        RMS_CommonUtil.pageAddMessage(ApexPages.severity.CONFIRM, '入库成功');
    }
    /**
     * 上传附件
     */
    public void upload()
    {
        // 检查input
        if (fileBody == null) {
            ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR, '请选择上传文件'));
            return;
        }
        attach = new Attachment();
        attach.parentid = this.order.id;
        attach.body = this.fileBody;
        attach.name = this.fileName;
        insert attach;

        RMS_CommonUtil.pageAddMessage(ApexPages.severity.CONFIRM, '附件上传成功');
    }
}