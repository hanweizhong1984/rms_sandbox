public with sharing class RTV_SummaryCtrl {
    
    // 当前summary
    public final Id summaryId {get; set;}
    public RTV_Summary__c summary {get; set;}
    
    // 当前summary的合计信息
    public class SummaryTotal {
        public Long Application_QTY {get; set;}
        public Decimal Application_Amount_NET {get; set;}
        public Decimal Application_Amount_CNY {get; set;}
        public Long Inspect_QTY_A {get; set;}
        public Long Inspect_QTY_B {get; set;}
        public Long Inspect_QTY_C {get; set;}
        public Long Inspect_QTY_D {get; set;}
        public Long Inbound_QTY {get; set;}
        public Decimal Actual_Amount_CNY {get; set;}
        public Decimal Actual_Amount_CNY_inV {get; set;}
    }
    public SummaryTotal summaryTotal {get; set;}
    
    //参数：recall
    // public Boolean recall{get; set;}
    // public Boolean sumRecall{get{return [SELECT Recall__c FROM RTV_Summary__c WHERE ID =:this.summaryId].Recall__c;}}
    
    // 各个状态的order
    public List<RTV_Order__c> orders_PostLf {get; set;}
    public List<RTV_Order__c> orders_Delivered {get; set;}
    public List<RTV_Order__c> orders_Inspected {get; set;}
    public List<RTV_Order__c> orders_InspWaitApproval {get; set;}
    public List<RTV_Order__c> orders_InsConfirmed {get; set;}
    public List<RTV_Order__c> orders_Inbound {get; set;}
    public List<RTV_Order__c> orders_Completed {get; set;}
    
    // 各个状态的order数量
    public Integer orders_PostLF_Cnt {get { return orders_PostLf.size(); } }
    public Integer orders_Delivered_Cnt {get { return orders_Delivered.size(); } }
    public Integer orders_Inspected_Cnt {get { return orders_Inspected.size(); } }
    public Integer orders_InspWaitApproval_Cnt {get { return orders_InspWaitApproval.size(); } }
    public Integer orders_InsConfirmed_Cnt {get { return orders_InsConfirmed.size(); } }
    public Integer orders_Inbound_Cnt {get { return orders_Inbound.size(); } }
    public Integer orders_Completed_Cnt {get { return orders_Completed.size(); } }
    
    // order的总数量
    public Integer orders_Cnt {get {
        return orders_PostLF_Cnt
            + orders_Delivered_Cnt
            + orders_Inspected_Cnt
            + orders_InspWaitApproval_Cnt
            + orders_InsConfirmed_Cnt
            + orders_Inbound_Cnt
            + orders_Completed_Cnt;
    }}
    
    /** 提交审批的表单 */
    public ApprovalForm approvalForm {get; set;}
    
    /** 提交Complete的表单 */
    public CompleteSummaryForm completeSummaryForm {get; set;}
    
    /** LoginUserInfo */
    public RMS_CommonUtil.LoginUserInfo loginUser = new RMS_CommonUtil.LoginUserInfo();
    public RMS_CommonUtil.LoginUserInfo getLoginUser() {return loginUser;}
    
    /** 构造方法 */
    public RTV_SummaryCtrl(ApexPages.StandardController stCtrl) {
        this.summaryId = stCtrl.getId();
        this.completeSummaryForm = new CompleteSummaryForm(this);
        this.approvalForm = new ApprovalForm(this); 
        this.summaryTotal = new SummaryTotal();
    }
    
    /** 初期化 */
    public void loadPage() {
        // summary信息
        this.summary = [
            SELECT Name, Status__c, OwnerId, Owner.Name, Recall__c,
                RTV_Program__r.ExRate__c,
                Insp_CS_Approve_Required__c, 
                Insp_CS_Approve_Time__c,
                Insp_Submit_Time__c, 
                CS_Inbound_Date__c, LF_DELY_Inbound_Date__c,
                LF_WH_Inbound_Date__c,Inspect_QTY_C__c
            FROM RTV_Summary__c WHERE Id = :this.summaryId
        ];
        
        // summary合计
        List<AggregateResult> orderTotals = [
            SELECT Return_Summary__c,
                SUM(Application_QTY__c) Application_QTY__c, 
                SUM(Application_Amount__c) Application_Amount_NET,
                SUM(Inspect_QTY_A__c) Inspect_QTY_A__c,
                SUM(Inspect_QTY_B__c) Inspect_QTY_B__c,
                SUM(Inspect_QTY_C__c) Inspect_QTY_C__c,
                SUM(Inspect_QTY_D__c) Inspect_QTY_D__c,
                SUM(Inbound_QTY__c) Inbound_QTY__c,
                SUM(Inbound_Amount__c) Actual_Amount_CNY__c,
                SUM(Actual_Amount_inV__c) Actual_Amount_CNY_inV__c
            FROM RTV_Order__c
            WHERE Return_Summary__c = :this.summary.Id
            GROUP BY Return_Summary__c
            LIMIT 1
        ];
        if (!orderTotals.isEmpty()) {
            AggregateResult orderTotal = orderTotals[0];
            // 申请合计
            this.summaryTotal.Application_QTY = ((Decimal)orderTotal.get('Application_QTY__c')).round();
            this.summaryTotal.Application_Amount_NET = (Decimal)orderTotal.get('Application_Amount_NET');
            this.summaryTotal.Application_Amount_CNY = (Decimal)orderTotal.get('Application_Amount_NET') * this.summary.RTV_Program__r.ExRate__c;
            
            // 质检数
            this.summaryTotal.Inspect_QTY_A = ((Decimal)orderTotal.get('Inspect_QTY_A__c')).round();
            this.summaryTotal.Inspect_QTY_B = ((Decimal)orderTotal.get('Inspect_QTY_B__c')).round();
            this.summaryTotal.Inspect_QTY_C = ((Decimal)orderTotal.get('Inspect_QTY_C__c')).round();
            this.summaryTotal.Inspect_QTY_D = ((Decimal)orderTotal.get('Inspect_QTY_D__c')).round();
            // 入库数
            this.summaryTotal.Inbound_QTY = ((Decimal)orderTotal.get('Inbound_QTY__c')).round();
            // 实际退货金额
            this.summaryTotal.Actual_Amount_CNY = (Decimal)orderTotal.get('Actual_Amount_CNY__c');
            this.summaryTotal.Actual_Amount_CNY_inV = (Decimal)orderTotal.get('Actual_Amount_CNY_inV__c');
        }
        
        // orderlist
        this.orders_PostLf = [
            SELECT Id, Name, Ship_To__r.Name, Earliest_Delivery_Date__c, 
                Application_QTY__c, Have_Read_Delivery_Report__c
            FROM RTV_Order__c
            WHERE Return_Summary__c = :this.summaryId AND Status__c = 'POST to LF'
        ];
        
        this.orders_Delivered = [
            SELECT Id, Name, Ship_To__r.Name, Application_QTY__c, Delivery_QTY__c
            FROM RTV_Order__c
            WHERE Return_Summary__c = :this.summaryId AND Status__c = 'Delivered'
        ];
        
        this.orders_Inspected = [
            SELECT Id, Name, Ship_To__r.Name, Application_QTY__c, 
                Inspect_QTY_A_Rd__c, Inspect_QTY_B_Rd__c, Inspect_QTY_C_Rd__c, Inspect_QTY_D_Rd__c
            FROM RTV_Order__c
            WHERE Return_Summary__c = :this.summaryId AND Status__c = 'Inspected'
        ];
        
        this.orders_InspWaitApproval = [
            SELECT Id, Name, Ship_To__r.Name, 
                Inspect_QTY_A_Rd__c, Inspect_QTY_B_Rd__c, Inspect_QTY_C_Rd__c, Inspect_QTY_D_Rd__c, 
                TBD_Count__c, Not_Found_Count__c
            FROM RTV_Order__c
            WHERE Return_Summary__c = :this.summaryId AND Status__c = 'Insp Wait Approval'
        ];
        
        this.orders_InsConfirmed = [
            SELECT Id, Name, Ship_To__r.Name, 
                Inspect_QTY_A_Rd__c, Inspect_QTY_B_Rd__c, Inspect_QTY_C_Rd__c, Inspect_QTY_D_Rd__c,
                TBD_Count__c, Not_Found_Count__c
            FROM RTV_Order__c
            WHERE Return_Summary__c = :this.summaryId AND Status__c = 'Insp Confirmed'
        ];
        
        this.orders_Inbound = [
            SELECT Id, Name, Ship_To__r.Name, 
                Inspect_QTY_A_Rd__c, Inspect_QTY_B_Rd__c, Inspect_QTY_C_Rd__c, Inspect_QTY_D_Rd__c, 
                Inbound_QTY__c
            FROM RTV_Order__c
            WHERE Return_Summary__c = :this.summaryId AND Status__c = 'Inbound'
        ];
        
        this.orders_Completed = [
            SELECT Id, Name, Ship_To__r.Name, 
                Inspect_QTY_A_Rd__c, Inspect_QTY_B_Rd__c, Inspect_QTY_C_Rd__c, Inspect_QTY_D_Rd__c, 
                Inbound_QTY__c
            FROM RTV_Order__c
            WHERE Return_Summary__c = :this.summaryId AND Status__c = 'Completed'
        ];
    }
    
    /** 更新summary以及对应item的recall */
    public void updateRecall() {
        //checkbox勾选后改变summary的Recall
        update new RTV_Summary__c(Id=this.summaryId, Recall__c=this.summary.Recall__c);
        //同步更新summary下对应item的recall状态
        List<RTV_Order_Item__c> orderitemList = new List<RTV_Order_Item__c>();

        for(RTV_Order_Item__c item:[SELECT Id,Recall__c FROM RTV_Order_Item__c WHERE RTV_Order__r.Return_Summary__C = :this.summaryId])
        {
            RTV_Order_Item__c newItem = new RTV_Order_Item__c();
            newItem.id = item.Id;
            newItem.Recall__c = this.summary.Recall__c;
            orderitemList.add(newItem);
        }
        //更新item
        update orderitemList;
    }
    
    /** 提交审批的表单 */
    public class ApprovalForm {
        private final RTV_SummaryCtrl ctrl;
        public Boolean isOpening {get; set;}
        public String error {get; set;}
        
        // 备注
        public String comment {get; set;}
        
        // LF的checkbox
        public Boolean isSubmiterChecked {get; set;}
        
        // 下一个审批Step
        public String nextApprover {get; set;}
        public ApexPages.SelectOption[] nextApproverOpts {get; set;}
        
        /** 构造 */
        public ApprovalForm(RTV_SummaryCtrl ctrl) {
            this.ctrl = ctrl;
        }
        /** open */
        public void open() {
            this.isOpening = true;
            this.error = null;
            this.comment = null;
            this.isSubmiterChecked = false;
            
            this.nextApprover = null;
            this.nextApproverOpts = new ApexPages.SelectOption[]{
                new ApexPages.SelectOption('RMS CS', 'RMS CS'),
                new ApexPages.SelectOption(this.ctrl.summary.Owner.Name, this.ctrl.summary.Owner.Name)
            };
        }
        /** close */
        public void close() {
            this.isOpening = false;
        }
        /** 提交待审批 */
        public ApexPages.Pagereference submit() {
            this.error = null;
            
            try {
                // 检查checkbox
                if (this.isSubmiterChecked != true) {
                    throw new RMS_CommonUtil.RMSException('请勾选[质检结果已确认]');
                }
                // 如果不许要CS审批时，检查页面的审批人
                if (this.ctrl.summary.Insp_CS_Approve_Required__c == false) {
                    this.checkNextApprover();
                }
                
                // 创建审批请求
                Approval.ProcessSubmitRequest req1 = new Approval.ProcessSubmitRequest();
                req1.setObjectId(this.ctrl.summaryId);
                req1.setComments(this.comment);
                Approval.process(req1);
                
                // 刷新页面
                ApexPages.Pagereference page = new ApexPages.Pagereference('/' + this.ctrl.summaryId);
                page.setRedirect(true);
                return page;
            } 
            catch(RMS_CommonUtil.RMSException err) {
                this.error = err.getMessage();
            }
            catch(DmlException err) {
                this.error = err.getDmlMessage(0);
            }
            return null;
        }
        
        /** 手动指定的审批人是CS时，更新summary的'需要cs审批属性'，使审批流执行step1 */
        private void checkNextApprover() {
            if (this.nextApprover == null) {
                throw new RMS_CommonUtil.RMSException('请选择一个审批人');
            }
            
            // 审批人是CS时
            if (this.nextApprover == 'RMS CS') {
                
                // 更新summary的'需要cs审批属性'，使审批流执行step1
                RTV_Summary__c updSum = new RTV_Summary__c();
                updSum.Id = this.ctrl.summaryId;
                updSum.Insp_CS_Approve_Required__c = true;
                update updSum;
                
                this.ctrl.summary.Insp_CS_Approve_Required__c = true;
            }
        }
    }
    
    /** CompleteSummary表单 */
    public class CompleteSummaryForm {
        private final RTV_SummaryCtrl ctrl;
        public Boolean isOpening {get; set;}
        
        public CompleteSummaryForm(RTV_SummaryCtrl ctrl) {
            this.ctrl = ctrl;
        }
        public void open() {
            this.isOpening = true;
        }
        public void close() {
            this.isOpening = false;
        }
        /** 将summary和其下所有的order变为completed */
        public ApexPages.Pagereference submit() {
            RTV_Summary__c updS = new RTV_Summary__c();
            updS.Id = this.ctrl.summaryId;
            updS.Status__c = 'Completed';
            update updS;
            
            // 刷新页面
            ApexPages.Pagereference page = new ApexPages.Pagereference('/' + this.ctrl.summaryId);
            page.setRedirect(true);
            return page;
        }
    }
}