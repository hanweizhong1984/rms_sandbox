public with sharing class RTV_SummaryCtrl_DTC {
    
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
   
    // 各个状态的order
    public List<RTV_Order__c> orders_Ready {get; set;}
    public List<RTV_Order__c> orders_PostLf {get; set;}
    public List<RTV_Order__c> orders_Delivered {get; set;}
    public List<RTV_Order__c> orders_Inspected {get; set;}
    public List<OrderInfo> orders_InspWaitApproval {get; set;}
    public List<RTV_Order__c> orders_InsConfirmed {get; set;}
    public List<RTV_Order__c> orders_Inbound {get; set;}
    public List<RTV_Order__c> orders_Completed {get; set;}
    
    // 各个状态的order数量
    public Integer orders_Ready_Cnt {get { return orders_Ready.size(); } }
    public Integer orders_PostLF_Cnt {get { return orders_PostLf.size(); } }
    public Integer orders_Delivered_Cnt {get { return orders_Delivered.size(); } }
    public Integer orders_Inspected_Cnt {get { return orders_Inspected.size(); } }
    public Integer orders_InspWaitApproval_Cnt {get { return orders_InspWaitApproval.size(); } }
    public Integer orders_InsConfirmed_Cnt {get { return orders_InsConfirmed.size(); } }
    public Integer orders_Inbound_Cnt {get { return orders_Inbound.size(); } }
    public Integer orders_Completed_Cnt {get { return orders_Completed.size(); } }
    
    // order的总数量
    public Integer orders_Cnt {get {
        return orders_Ready_Cnt
            + orders_PostLF_Cnt
            + orders_Delivered_Cnt
            + orders_Inspected_Cnt
            + orders_InspWaitApproval_Cnt
            + orders_InsConfirmed_Cnt
            + orders_Inbound_Cnt
            + orders_Completed_Cnt;
    }}
    
    /** 表单 */ 
    public CreateOrderForm createOrderForm {get; set;}
    /** 提交审批的表单 */
    public ApprovalSubmitForm appSubmitForm {get; set;}
    /** 提交审批的表单 */
    public ApprovalForm approveForm {get; set;}
    
    /** LoginUserInfo */
    public RMS_CommonUtil.LoginUserInfo loginUser = new RMS_CommonUtil.LoginUserInfo();
    public RMS_CommonUtil.LoginUserInfo getLoginUser() {return loginUser;}
    
    /** 构造方法 */
    public RTV_SummaryCtrl_DTC(ApexPages.StandardController stCtrl) {
        this.summaryId = stCtrl.getId();
        this.createOrderForm = new CreateOrderForm(this);
        this.appSubmitForm = new ApprovalSubmitForm(this); 
        this.approveForm = new ApprovalForm(this); 
        this.summaryTotal = new SummaryTotal();
    }
    
    /** 初期化 */
    public void loadPage() {
        // summary信息
        this.summary = [
            SELECT Name, Status__c, OwnerId, Owner.Name, Recall__c, DTC_Type__c,
                Account_Group__c, Account_Group__r.Name,
                RTV_Program__r.Name, RTV_Program__r.ExRate__c,
                Insp_CS_Approve_Required__c, 
                Insp_CS_Approve_Time__c,
                Insp_Submit_Time__c, 
                CS_Inbound_Date__c, LF_DELY_Inbound_Date__c, LF_WH_Inbound_Date__c
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
        this.orders_Ready = [
            SELECT Id, Name, Ship_To__r.Name, Ship_To__r.DTC_Code__c, Ship_To__r.Sales_Channel__c,
                Earliest_Delivery_Date__c, Application_QTY__c
            FROM RTV_Order__c
            WHERE Return_Summary__c = :this.summaryId AND Status__c = 'Ready'
        ];
        
        this.orders_PostLf = [
            SELECT Id, Name, Ship_To__r.Name, Ship_To__r.DTC_Code__c, Ship_To__r.Sales_Channel__c,
                Earliest_Delivery_Date__c, Application_QTY__c, Have_Read_Delivery_Report__c
            FROM RTV_Order__c
            WHERE Return_Summary__c = :this.summaryId AND Status__c = 'POST to LF'
        ];
        
        this.orders_Delivered = [
            SELECT Id, Name, Ship_To__r.Name, Ship_To__r.DTC_Code__c, Ship_To__r.Sales_Channel__c,
                Application_QTY__c, Delivery_QTY__c
            FROM RTV_Order__c
            WHERE Return_Summary__c = :this.summaryId AND Status__c = 'Delivered'
        ];
        
        this.orders_Inspected = [
            SELECT Id, Name, Ship_To__r.Name, Ship_To__r.DTC_Code__c, Ship_To__r.Sales_Channel__c,
                Application_QTY__c, 
                Inspect_QTY_A_Rd__c, Inspect_QTY_B_Rd__c, Inspect_QTY_C_Rd__c, Inspect_QTY_D_Rd__c
            FROM RTV_Order__c
            WHERE Return_Summary__c = :this.summaryId AND Status__c = 'Inspected'
        ];
        
        queryOrderApprovalInfo([
            SELECT Id, Name, Ship_To__r.Name, Ship_To__r.DTC_Code__c, Ship_To__r.Sales_Channel__c,
                Status__c, Inspect_QTY_A_Rd__c, Inspect_QTY_B_Rd__c, Inspect_QTY_C_Rd__c, Inspect_QTY_D_Rd__c,
                (SELECT Id FROM ProcessInstances ORDER BY CreatedDate DESC LIMIT 1)
            FROM RTV_Order__c
            WHERE Return_Summary__c = :this.summaryId AND Status__c = 'Insp Wait Approval'
            AND From_Takeback_Order__c = null
        ]);
        
        this.orders_InsConfirmed = [
            SELECT Id, Name, Ship_To__r.Name, Ship_To__r.DTC_Code__c, Ship_To__r.Sales_Channel__c,
                Inspect_QTY_A_Rd__c, Inspect_QTY_B_Rd__c, Inspect_QTY_C_Rd__c, Inspect_QTY_D_Rd__c,
                TBD_Count__c, Not_Found_Count__c
            FROM RTV_Order__c
            WHERE Return_Summary__c = :this.summaryId AND Status__c = 'Insp Confirmed'
        ];
        
        this.orders_Inbound = [
            SELECT Id, Name, Ship_To__r.Name, Ship_To__r.DTC_Code__c, Ship_To__r.Sales_Channel__c,
                Inspect_QTY_A_Rd__c, Inspect_QTY_B_Rd__c, Inspect_QTY_C_Rd__c, Inspect_QTY_D_Rd__c, 
                Inbound_QTY__c
            FROM RTV_Order__c
            WHERE Return_Summary__c = :this.summaryId AND Status__c = 'Inbound'
        ];
        
        this.orders_Completed = [
            SELECT Id, Name, Ship_To__r.Name, Ship_To__r.DTC_Code__c, Ship_To__r.Sales_Channel__c,
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
    
    /** 检索各个order的审批状态 */
    public void queryOrderApprovalInfo(List<RTV_Order__c> orders) {
        Map<Id, OrderInfo> approveInfoMap = new Map<Id, OrderInfo>();
        Set<Id> processingIds = new Set<Id>();
        
        // 检索order
        for (RTV_Order__c order: orders) {
            // 统计order信息
            OrderInfo info = new OrderInfo();
            info.order = order;
            approveInfoMap.put(order.id, info);
            
            // 统计进行中的processId
            if (!order.ProcessInstances.isEmpty()) {
                processingIds.add(order.ProcessInstances[0].id);
            }
        }
        
        // 检索审批中的process
        for (ProcessInstance process: [ 
            SELECT TargetObjectId, LastModifiedDate, Status, (
                SELECT Id, ProcessNode.Name, ActorId, Actor.Name, StepStatus, Comments, CreatedDate
                FROM StepsAndWorkitems
                WHERE IsPending = True
                ORDER BY CreatedDate
                LIMIT 1
            )
            FROM ProcessInstance
            WHERE Id IN :processingIds
        ]) {
            OrderInfo info = approveInfoMap.get(process.TargetObjectId);
            
            if (process.StepsAndWorkitems.Size() > 0) {
                info.nextApprovalStep = process.StepsAndWorkitems[0];
            }
        }
        this.orders_InspWaitApproval = approveInfoMap.values();
        
        // 待审批work
        if (loginUser.isSysAdmin) {
            this.approveForm.workItems = [
                SELECT Id, ProcessInstance.TargetObjectId
                FROM ProcessInstanceWorkItem 
                WHERE ProcessInstance.TargetObjectId IN :approveInfoMap.KeySet()
            ];
        } else {
            this.approveForm.workItems = [
                SELECT Id, ProcessInstance.TargetObjectId
                FROM ProcessInstanceWorkItem 
                USING SCOPE mine_and_my_groups
                WHERE ProcessInstance.TargetObjectId IN :approveInfoMap.KeySet()
            ];
        }
    }
    
    /**
     * 表单:创建Order
     */
    public class CreateOrderForm {
        private RTV_SummaryCtrl_DTC ctrl;
        public Boolean isOpening {get; set;}
        public String error {get; set;}
        
        // order.recordtypes
        public final Map<String, RecordType> orderTypes = RMS_CommonUtil.getRecordTypes('RTV_Order__c');
        
        // form.input: shipTo.Code
        public String inputShipToCode {get; set;}
        public String inputStoreCode {get; set;}
        
        /** 构造 */
        public CreateOrderForm(RTV_SummaryCtrl_DTC ctrl) {
            this.ctrl = ctrl;
        }
        /** 模态框open */
        public void open() {
            this.isOpening = true;
            this.error = '';
            this.inputShipToCode = '';
            this.inputStoreCode = '';
        }
        /** 模态框close */
        public void close() {
            this.isOpening = false;
        }
        /** 创建Order */
        public RTV_Order__c createOrder() {
            try {
                // 获取shipTo
                RMS_Ship_To__c shipTo = queryShipTo();
                
                // 获取orderType
                String orderType = 
                    this.ctrl.summary.DTC_Type__c == 'CFS'? 'CFS DTC Takeback': 
                    this.ctrl.summary.DTC_Type__c == 'Digital'? 'Digital DTC Takeback': '';
                if (orderType == '') {
                    throw new RMS_CommonUtil.RMSException('异常! Summary.DTC_Type__c的值错误!');
                }
                
                // 获取授权码
                String programName = this.ctrl.summary.RTV_Program__r.Name;
                String accGrpName =  this.ctrl.summary.Account_Group__r.Name;
                String orderCode = 
                    this.ctrl.summary.DTC_Type__c == 'CFS'? RMS_CommonUtil.order_getCode(programName, accGrpName, shipTo.DTC_Code__c): 
                    this.ctrl.summary.DTC_Type__c == 'Digital'? RMS_CommonUtil.order_getCode(programName.substring(0, 1), accGrpName, shipTo.Name): '';
                
                // ----------------------
                // 创建order
                // ----------------------
                RTV_Order__c newOrder = new RTV_Order__c();
                newOrder.Return_Summary__c = this.ctrl.summary.Id;
                newOrder.name = orderCode;
                newOrder.Sold_To__c = shipTo.Sold_To_Code__c;
                newOrder.Ship_To__c = shipTo.Id;
                newOrder.RecordTypeId = this.orderTypes.get('DTC Takeback Ready').Id;
                newOrder.Order_Type__c = orderType;
                newOrder.Status__c = 'Ready';
                newOrder.Ship_To_Contact__c = shipTo.SAP_Customer_Name__c;
                newOrder.Ship_To_Phone1__c = shipTo.SAP_Tel__c;
                newOrder.Ship_To_Phone2__c = '';
                newOrder.Ship_To_Address__c = shipTo.SAP_Addr__c;
                // newOrder.OwnerId = shipTo.OwnerId; //与ShipTo的Owner无关，由创建人去管理和审批自己的Order
                insert newOrder;
                
                return newOrder;
            } 
            catch (DmlException err) {
                if (err.getDmlType(0) == StatusCode.DUPLICATE_VALUE) {
                    this.error = '授权码重复，该ShipTo已存在其它今日申请的订单，请次日再申请。';
                } else {
                    this.error = err.getDmlMessage(0);
                }
            }
            catch (Exception err) {
                this.error = err.getMessage();
            }
            return null;
        }
        /** 提交 */
        public ApexPages.Pagereference submit() {
            RTV_Order__c order = this.createOrder();
            if (order != null) {
                return new ApexPages.Pagereference('/' + this.ctrl.summary.Id);
            }
            return null;
        }
        /** 检索shipTo */
        public RMS_Ship_To__c queryShipTo() {
            List<RMS_Ship_To__c> shipTos = new List<RMS_Ship_To__c>();
            
            // CFS 通过 Store 查询
            if (this.ctrl.summary.DTC_Type__c == 'CFS') {
                shipTos = [
                    SELECT Id, Name, Code_Add__c, OwnerId, IsDtcValid__c, DTC_Code__c,
                        Sold_To_Code__c, Sold_To_Code__r.Name, Sold_To_Code__r.Account_Group__c,
                        Contact_Pr__c, Contact_Tel1__c, Contact_Tel2__c, Dely_Addr__c,
                        SAP_Customer_Name__c, SAP_Tel__c, SAP_Addr__c
                    FROM RMS_Ship_To__c
                    WHERE DTC_Code__c = :this.inputStoreCode
                    LIMIT 1
                ];
                if (shipTos.isEmpty()) {
                    throw new RMS_CommonUtil.RMSException('无法找到 Store: ' + this.inputStoreCode);
                }
            } 
            // Digital 通过 ShipTo 查询
            else {
                shipTos = [
                    SELECT Id, Name, Code_Add__c, OwnerId, IsDtcValid__c, DTC_Code__c,
                        Sold_To_Code__c, Sold_To_Code__r.Name, Sold_To_Code__r.Account_Group__c,
                        Contact_Pr__c, Contact_Tel1__c, Contact_Tel2__c, Dely_Addr__c,
                        SAP_Customer_Name__c, SAP_Tel__c, SAP_Addr__c
                    FROM RMS_Ship_To__c
                    WHERE Name = :this.inputShipToCode
                    LIMIT 1
                ];
                if (shipTos.isEmpty()) {
                    throw new RMS_CommonUtil.RMSException('无法找到 Ship-to: ' + this.inputShipToCode);
                }
            }
            // 检查shipto
            RMS_Ship_To__c shipTo = shipTos[0];
            // 检查shipto.accountgruop
            if (shipto.Sold_To_Code__r.Account_Group__c != this.ctrl.summary.Account_Group__c) {
                throw new RMS_CommonUtil.RMSException('该Ship-to "'+ shipTo.Name +'" 不属于这个 Account Group: "' + this.ctrl.summary.Account_Group__r.Name + '"');
            }
            // 检查shipto.是否有效
            if (shipTo.IsDtcValid__c == false) {
                throw new RMS_CommonUtil.RMSException('对不起，该Ship-to "'+ shipTo.Name +'" 不是有效的 DTC Ship-to');
            }
            return shipTo;
        }
    }
    
    /**
     * 表单:提交审批
     */
    public class ApprovalSubmitForm {
        private final RTV_SummaryCTRL_DTC ctrl;
        public Boolean isOpening {get; set;}
        public String error {get; set;}
        
        // 备注
        public String comment {get; set;}
        
        // LF的checkbox
        public Boolean isSubmiterChecked {get; set;}
        
        /** 构造 */
        public ApprovalSubmitForm(RTV_SummaryCTRL_DTC ctrl) {
            this.ctrl = ctrl;
        }
        /** open */
        public void open() {
            this.isOpening = true;
            this.error = null;
            this.comment = null;
            this.isSubmiterChecked = false;
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
                
                // 每个Order单独创建审批请求
                List<Approval.ProcessSubmitRequest> submits = new List<Approval.ProcessSubmitRequest>();
                for (RTV_Order__c order: this.ctrl.orders_Inspected) {
                    Approval.ProcessSubmitRequest submit = new Approval.ProcessSubmitRequest();
                    submit.setObjectId(order.Id);
                    submit.setComments(this.comment);
                    submits.add(submit);
                }
                List<Approval.ProcessResult> proResults = Approval.process(submits);
                
                // 检查结果
                for (Approval.ProcessResult res: proResults) {
                    if (res.isSuccess() == false) {
                        throw new RMS_CommonUtil.RMSException(res.getErrors()[0].getMessage());
                    }
                }
                
                // 刷新页面
                ApexPages.Pagereference page = new ApexPages.Pagereference('/' + this.ctrl.summaryId);
                page.setRedirect(true);
                return page;
            }
            catch(Exception err) {
                this.error = err.getMessage();
            }
            return null;
        }
    }
    
    /**
     * 表单:提交审批
     */
    public class ApprovalForm {
        private final RTV_SummaryCTRL_DTC ctrl;
        public Boolean isOpening {get; set;}
        public String error {get; set;}
        
        /** 需要当前user审批的work */
        public List<ProcessInstanceWorkItem> workItems {get; set;}
        public Integer workItemsCnt {get {return workItems.size();}}
        
        // 备注
        public String comment {get; set;}
        
        /** 构造 */
        public ApprovalForm(RTV_SummaryCTRL_DTC ctrl) {
            this.ctrl = ctrl;
        }
        /** open */
        public void open() {
            this.isOpening = true;
            this.error = null;
            this.comment = null;
        }
        /** close */
        public void close() {
            this.isOpening = false;
        }
        /** 审批 */
        public ApexPages.Pagereference approve() {
            if (approvalAction('Approve')) {
                // 刷新页面
                ApexPages.Pagereference page = new ApexPages.Pagereference('/' + this.ctrl.summaryId);
                page.setRedirect(true);
                return page;
            } else {
                return null;
            }
        }
        /** 拒绝 */
        public ApexPages.Pagereference reject() {
            if (approvalAction('Reject')) {
                // 刷新页面
                ApexPages.Pagereference page = new ApexPages.Pagereference('/' + this.ctrl.summaryId);
                page.setRedirect(true);
                return page;
            } else {
                return null;
            }
        }
        /** 执行审批处理 */
        private Boolean approvalAction(String action) {
            this.error = null;
            try {
                // 每个Order单独创建审批请求
                List<Approval.ProcessWorkitemRequest> reqs = new List<Approval.ProcessWorkitemRequest>();
                for (ProcessInstanceWorkItem workitem: this.workItems) {
                   // 创建审批请求
                    Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
                    req.setComments(this.comment);
                    req.setAction(action);
                    req.setWorkitemId(workitem.Id);
                    reqs.add(req);
                }
                List<Approval.ProcessResult> proResults = Approval.process(reqs);
                // 检查结果
                for (Approval.ProcessResult res: proResults) {
                    if (res.isSuccess() == false) {
                        throw new RMS_CommonUtil.RMSException(res.getErrors()[0].getMessage());
                    }
                }
                return true;
            }
            catch(Exception err) {
                this.error = err.getMessage();
            }
            return false;
        }
    }
    public class OrderInfo {
        public RTV_Order__c order {get; set;}
        public ProcessInstanceHistory nextApprovalStep {get; set;}
    }
}