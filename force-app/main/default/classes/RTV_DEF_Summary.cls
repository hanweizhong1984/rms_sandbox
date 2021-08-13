public inherited sharing class RTV_DEF_Summary {
    // DEF_Summary
    public final Id summaryId {get; set;}
    public RTV_DEF_Summary__c summary {get; set;}

    // 是否入库判断
    public Boolean inboundFlg {get; set;}
    
    // 各个状态的order
    public List<RTV_Order__c> orders_Ready {get; set;}
    public List<RTV_Order__c> orders_PostLf {get; set;}
    public List<RTV_Order__c> orders_Delivered {get; set;}
    public List<RTV_Order__c> orders_Inspected {get; set;}
    public List<OrderInfo> orders_InspWaitApproval {get; set;}
    public List<RTV_Order__c> orders_FromTBWaitApproval {get; set;}
    public List<RTV_Order__c> orders_InsConfirmed {get; set;}
    public List<RTV_Order__c> orders_Inbound {get; set;}
    public List<RTV_Order__c> orders_Completed {get; set;}
    
    // 各个状态的order数量
    public Integer orders_Ready_Cnt {get { return orders_Ready.size(); } }
    public Integer orders_PostLF_Cnt {get { return orders_PostLf.size(); } }
    public Integer orders_Delivered_Cnt {get { return orders_Delivered.size(); } }
    public Integer orders_Inspected_Cnt {get { return orders_Inspected.size(); } }
    public Integer orders_InspWaitApproval_Cnt {get { return orders_InspWaitApproval.size(); } }
    public Integer orders_FromTBWaitApproval_Cnt {get { return orders_FromTBWaitApproval.size(); } }
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
            + orders_FromTBWaitApproval_Cnt
            + orders_InsConfirmed_Cnt
            + orders_Inbound_Cnt
            + orders_Completed_Cnt;
    }}
    
    // 表单
    public CreateOrderForm createOrderForm {get; set;}  //创建order
    
    // 提交审批表单
    public ApprovalSubmitForm appSubmitForm {get; set;}  
    public ApprovalForm approveForm {get; set;} 
    
    // TB转DEF审批表单
    public Tb2DefConfirmForm tb2defForm {get; set;}
    
    /** LoginUserInfo */
    public RMS_CommonUtil.LoginUserInfo loginUser = new RMS_CommonUtil.LoginUserInfo();
    public RMS_CommonUtil.LoginUserInfo getLoginUser() {return loginUser;}
    
    /**
     * 构造方法
     */
    public RTV_DEF_Summary(ApexPages.StandardController stCtrl) {
        this.summaryId = stCtrl.getId();
        this.createOrderForm = new CreateOrderForm(this);
        this.appSubmitForm = new ApprovalSubmitForm(this);
        this.approveForm = new ApprovalForm(this);
        this.tb2defForm = new Tb2DefConfirmForm(this);
    }
    /**
     * 载入页面数据
     */
    public void loadPage() {
        this.summary = [
            SELECT Id, Name, Active_Status__c, Account_Group__c, Account_Group__r.Name, 
                Insp_Submit_Time__c, Insp_CS_Approve_Time__c,
                LF_WH_Inbound_Date__c, CS_Inbound_Date__c, LF_DELY_Inbound_Date__c
            FROM RTV_DEF_Summary__c WHERE Id = :this.summaryId
        ];
        
        this.orders_Ready = [
            SELECT Id, Name, Sold_To__r.Name, Ship_To__r.Name, Application_QTY__c, Application_Amount__c
            FROM RTV_Order__c
            WHERE RTV_DEF_Summary__c = :this.summaryId AND Status__c = 'Ready'
        ];
        
        this.orders_PostLf = [
            SELECT Id, Name, Sold_To__r.Name, Ship_To__r.Name, Earliest_Delivery_Date__c, 
                Application_QTY__c, Have_Read_Delivery_Report__c
            FROM RTV_Order__c
            WHERE RTV_DEF_Summary__c = :this.summaryId AND Status__c = 'POST to LF'
        ];
        
        this.orders_Delivered = [
            SELECT Id, Name, Sold_To__r.Name, Ship_To__r.Name, Application_QTY__c, Delivery_QTY__c
            FROM RTV_Order__c
            WHERE RTV_DEF_Summary__c = :this.summaryId AND Status__c = 'Delivered'
        ];
        
        this.orders_Inspected = [
            SELECT Id, Name, Sold_To__r.Name, Ship_To__r.Name, Application_QTY__c, 
                Inspect_QTY_C_Rd__c, Inspect_QTY_D_Rd__c
            FROM RTV_Order__c
            WHERE RTV_DEF_Summary__c = :this.summaryId AND Status__c = 'Inspected'
        ];
        
        this.queryOrderApprovalInfo();
        
        this.orders_FromTBWaitApproval = [
            SELECT Id, Name, Sold_To__r.Name, Ship_To__r.Name, 
                RTV_Defective__c, RTV_Defective_FW__c, Off_Policy__c, Off_Policy_FW__c,
                Actual_Date_Of_WSL_Confirmed__c,
                TBD_Count__c, Not_Found_Count__c, Selling_Price_Error_Count__c,
                Inspect_QTY_C_Rd__c, Inspect_QTY_D_Rd__c,
                Inbound_QTY__c, Inbound_Amount__c, From_Takeback_Order__c
            FROM RTV_Order__c
            WHERE RTV_DEF_Summary__c = :this.summaryId AND Status__c = 'Insp Wait Approval'
            AND From_Takeback_Order__c != null
        ];
        
        this.orders_InsConfirmed = [
            SELECT Id, Name, Sold_To__r.Name, Ship_To__r.Name, 
                RTV_Defective__c, RTV_Defective_FW__c, Off_Policy__c, Off_Policy_FW__c,
                Actual_Date_Of_WSL_Confirmed__c,
                Inspect_QTY_C_Rd__c, Inspect_QTY_D_Rd__c,
                Inbound_QTY__c, Inbound_Amount__c, From_Takeback_Order__c
            FROM RTV_Order__c
            WHERE RTV_DEF_Summary__c = :this.summaryId AND Status__c = 'Insp Confirmed'
        ];
        
        this.orders_Inbound = [
            SELECT Id, Name, Sold_To__r.Name, Ship_To__r.Name, 
                RTV_Defective__c, RTV_Defective_FW__c, Off_Policy__c, Off_Policy_FW__c,
                Actual_Date_Of_WSL_Confirmed__c,
                Inspect_QTY_C_Rd__c, Inspect_QTY_D_Rd__c,
                Inbound_QTY__c, Inbound_Amount__c, From_Takeback_Order__c
            FROM RTV_Order__c
            WHERE RTV_DEF_Summary__c = :this.summaryId AND Status__c = 'Inbound'
        ];
        
        this.orders_Completed = [
            SELECT Id, Name, Sold_To__r.Name, Ship_To__r.Name, 
                RTV_Defective__c, RTV_Defective_FW__c, Off_Policy__c, Off_Policy_FW__c,
                Actual_Date_Of_WSL_Confirmed__c,
                Inspect_QTY_C_Rd__c, Inspect_QTY_D_Rd__c,
                Inbound_QTY__c, Inbound_Amount__c, From_Takeback_Order__c
            FROM RTV_Order__c
            WHERE RTV_DEF_Summary__c = :this.summaryId AND Status__c = 'Completed'
        ];

        this.inboundFlg = false;
        Integer allCnt = [SELECT COUNT() FROM RTV_Order__c WHERE RTV_DEF_Summary__c = :this.summaryId];
        if(allCnt == this.orders_InsConfirmed.size()){
            this.inboundFlg = true;
        }
    }

    /** 入库 */
    public ApexPages.Pagereference inbound() {
        return new ApexPages.Pagereference('/apex/RTV_DEF_Summary_Inbound?summaryId=' + this.summaryId);
    }
    
    /** 检索各个order的审批状态 */
    public void queryOrderApprovalInfo() {
        Map<Id, OrderInfo> approveInfoMap = new Map<Id, OrderInfo>();
        Set<Id> processingIds = new Set<Id>();
        
        // 检索order
        for (RTV_Order__c order: [
            SELECT Id, Name, Sold_To__r.Name, Ship_To__r.Name, Status__c, 
                Inspect_QTY_C_Rd__c, Inspect_QTY_D_Rd__c,
                TBD_Count__c, Not_Found_Count__c, Inbound_Amount__c,
                Ship_To_Out_Emails_Status__c,
                (SELECT Id FROM ProcessInstances ORDER BY CreatedDate DESC LIMIT 1)
            FROM RTV_Order__c
            WHERE RTV_DEF_Summary__c = :this.summaryId AND Status__c = 'Insp Wait Approval'
            AND From_Takeback_Order__c = null
        ]) {
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
        private RTV_DEF_Summary ctrl;
        public Boolean isOpening {get; set;}
        public String error {get; set;}
        
        // order.recordtypes
        public final Map<String, RecordType> orderTypes = RMS_CommonUtil.getRecordTypes('RTV_Order__c');
        
        // form.input: shipTo.Code
        public String inputShipToCode {get; set;}
        
        /** 构造 */
        public CreateOrderForm(RTV_DEF_Summary ctrl) {
            this.ctrl = ctrl;
        }
        /** 模态框open */
        public void open() {
            this.isOpening = true;
            this.inputShipToCode = '';
            
            // shipTo用户页面的默认值
            if (ctrl.loginUser.isShipto) {
                List<RMS_Ship_To__c> shipTos = [
                    SELECT Id, Name, Code_Add__c, Sold_To_Code__c, Sold_To_Code__r.Account_Group__c
                    FROM RMS_Ship_To__c
                    WHERE OwnerId = :UserInfo.getUserId()
                    LIMIT 1
                ];
                if (shipTos.size() > 0) {
                    this.inputShipToCode = shipTos[0].Name;
                }
            }
        }
        /** 模态框close */
        public void close() {
            this.isOpening = false;
        }
        /** 创建Order */
        public RTV_Order__c createOrder() {
            try {
                // 检查shipto
                List<RMS_Ship_To__c> shipTos = [
                    SELECT Id, Name, Code_Add__c, OwnerId, 
                        Sold_To_Code__c, Sold_To_Code__r.Name, Sold_To_Code__r.Account_Group__c,
                        Contact_Pr__c, Contact_Tel1__c, Contact_Tel2__c, Dely_Addr__c
                    FROM RMS_Ship_To__c
                    WHERE Name = :this.inputShipToCode
                    LIMIT 1
                ];
                if (shipTos.isEmpty()) {
                    this.error = '无法找到 Ship-to: ' + this.inputShipToCode;
                    return null;
                }
                RMS_Ship_To__c shipTo = shipTos[0];
                if (shipto.Sold_To_Code__r.Account_Group__c != this.ctrl.summary.Account_Group__c) {
                    this.error = '该Ship-to "'+ shipTo.Name +'" 不属于这个 Account Group: "' + this.ctrl.summary.Account_Group__r.Name + '"';
                    return null;
                }
                if (this.ctrl.loginUser.isWSL && shipto.OwnerId != UserInfo.getUserId()) {
                    this.error = '抱歉, 您不是该 Ship-to 的 Owner.';
                    return null;
                }
                
                // WSL用户不能创建重复的shipto
                if (this.ctrl.loginUser.isWSL) {
                    List<RTV_Order__c> extOrders = [
                        SELECT Id 
                        FROM RTV_Order__c
                        WHERE RTV_DEF_Summary__c = :this.ctrl.summary.Id
                        AND Ship_To__c = :shipTo.Id
                        AND CreatedBy.Profile.Name IN :this.ctrl.loginUser.Profiles_WSL
                    ];
                    if (!extOrders.isEmpty()) {
                        this.error = '已经存在 Ship-to "' + shipTo.Name + '" 的订单，请勿重复创建.';
                        return null;
                    }
                }
                
                // 创建order
                RTV_Order__c newOrder = new RTV_Order__c();
                newOrder.name = RMS_CommonUtil.defect_getCode(shipTo.Sold_To_Code__r.Name, shipTo.Name);
                newOrder.RTV_DEF_Summary__c = this.ctrl.summary.Id;
                newOrder.Sold_To__c = shipTo.Sold_To_Code__c;
                newOrder.Ship_To__c = shipTo.Id;
                newOrder.Ship_To_Address__c = shipTo.Code_Add__c;
                newOrder.RecordTypeId = this.orderTypes.get('RTV Defective Ready').Id;
                newOrder.Order_Type__c = 'RTV Defective';
                newOrder.Status__c = 'Ready';
                newOrder.Ship_To_Contact__c = shipTo.Contact_Pr__c;
                newOrder.Ship_To_Phone1__c = shipTo.Contact_Tel1__c;
                newOrder.Ship_To_Phone2__c = shipTo.Contact_Tel2__c;
                newOrder.Ship_To_Address__c = shipTo.Dely_Addr__c;
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
        /** 提交并开始上传PackingList */
        public ApexPages.Pagereference submitAndPacking() {
            RTV_Order__c order = this.createOrder();
            if (order != null) {
                return new ApexPages.Pagereference('/apex/RTV_Defective_UploadPackingList?id=' + order.Id);
            }
            return null;
        }
    }
    
    /**
     * 表单:提交审批
     */
    public class ApprovalSubmitForm {
        private final RTV_DEF_Summary ctrl;
        public Boolean isOpening {get; set;}
        public String error {get; set;}
        
        // 备注
        public String comment {get; set;}
        
        // LF的checkbox
        public Boolean isSubmiterChecked {get; set;}
        
        /** 构造 */
        public ApprovalSubmitForm(RTV_DEF_Summary ctrl) {
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
        private final RTV_DEF_Summary ctrl;
        public Boolean isOpening {get; set;}
        public String error {get; set;}
        
        /** 当前user的待审批work */
        public List<ProcessInstanceWorkItem> workItems {get; set;}
        public Integer workItemsCnt {get {return workItems.size();}}
        
        // 备注
        public String comment {get; set;}
        
        /** 构造 */
        public ApprovalForm(RTV_DEF_Summary ctrl) {
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
    
    /** TB转DEF的确认Form */
    public class Tb2DefConfirmForm {
        private final RTV_DEF_Summary ctrl;
        public Boolean isOpening {get; set;}
        public String error {get; set;}
        
        /** 构造 */
        public Tb2DefConfirmForm(RTV_DEF_Summary ctrl) {
            this.ctrl = ctrl;
        }
        /** open */
        public void open() {
            this.isOpening = true;
            this.error = null;
        }
        /** close */
        public void close() {
            this.isOpening = false;
        }
        /** 审批 */
        public ApexPages.Pagereference approve() {
            List<RTV_Order__c> updOrders = new List<RTV_Order__c>();
            
            // 遍历待审批Order
            for (RTV_Order__c order: this.ctrl.orders_FromTBWaitApproval) {
                // 检查错误
                if (order.Selling_Price_Error_Count__c > 0) {
                    this.error = '订单 "'+order.Name+'" 中存在 Selling Price 错误';
                    return null;
                }
                // 修改Order状态为审批完成
                updOrders.add(new RTV_Order__c(Id=order.Id, Status__c='Insp Confirmed'));
            }
            update updOrders;
            
            // 刷新页面
            ApexPages.Pagereference page = new ApexPages.Pagereference('/' + this.ctrl.summaryId);
            page.setRedirect(true);
            return page;
        }
    }
    
    public class OrderInfo {
        public RTV_Order__c order {get; set;}
        public ProcessInstanceHistory nextApprovalStep {get; set;}
    }
}