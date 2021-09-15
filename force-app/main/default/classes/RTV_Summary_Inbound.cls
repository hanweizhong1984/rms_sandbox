public with sharing class RTV_Summary_Inbound {
    /** LoginUserInfo */
    public RMS_CommonUtil.LoginUserInfo loginUser = new RMS_CommonUtil.LoginUserInfo();
    public RMS_CommonUtil.LoginUserInfo getLoginUser() {return loginUser;}

    public final String[] adminAttach = new String[]{'系统管理员', 'System Administrator', 'RMS Admin','RMS CS','RMS IDC LF'};
    public final String[] csAttach = new String[]{'RMS CS','RMS IDC LF'};
    public final String[] lfAttach = new String[]{'RMS IDC LF'};

    public final Id summaryId = ApexPages.currentPage().getParameters().get('summaryId');
    public RTV_Summary__c summary {get; set;}
    
    // orders
    public List<RTV_Order__c> orders {get; set;}
    
    // 待inbound的orderIds
    public Set<Id> workOrdersIds {get; set;}
    public Integer workOrdersCnt {get; set;}
    
    // D品入库的batch
    public AsyncApexJob job {get; set;}
    
    // 载入中
    public Boolean isLoading {get; set;}
    public Boolean isBatchLoading {get; set;}
    // 载入中(进度%)
    public Integer loadingPercent {get { return getJobPercent(this.job); }}

    //文件内容
    public transient Blob fileBody{get;set;}
    //文件名
    public String fileName{get;set;}

    public Date deliveryDate { 
        get {
            if (deliveryDate == null) {
                deliveryDate =  DateTime.now().date();
            }
            return deliveryDate;
        } 
        set;
    }

    // 附件ID
    public Id contentDocumentId {get;set;}

    /** 初期化 */
    public void loadPage() {
        String[] pnames = null;
        if(loginUser.isLF){
            pnames = lfAttach;
        }else if(loginUser.isCS){
            pnames = csAttach;
        }else if(loginUser.isAdmin){
            pnames = adminAttach;
        }
        this.summary = [
            SELECT Name, Requested_Delivery_Date__c, Recall__c, Inspect_QTY_C__c, Attach_User__c,Account_Group__c,Account_Group__r.Name,
            LF_WH_Inbound_Date__c, LF_DELY_Inbound_Date__c, CS_Inbound_Date__c, 
            LF_WH_Inbound_Comment__c, LF_DELY_Inbound_Comment__c, CS_Inbound_Comment__c, 
            (
                SELECT ContentDocumentId, ContentDocument.FileExtension, 
                ContentDocument.Description, ContentDocument.Owner.Name, ContentDocument.Owner.Profile.Name
                FROM ContentDocumentLinks WHERE ContentDocument.Owner.Profile.Name IN:pnames
            ) 
            FROM RTV_Summary__c WHERE Id = :this.summaryId
        ];
               
        this.orders = [
            SELECT Id, Name, OwnerId, Order_Auth_Code__c, Status__c,
                Sold_To__c, Ship_To__c, Ship_To__r.Name, 
                Delivery_QTY__c, Earliest_Delivery_Date__c, Return_Summary__c,
                Inspect_QTY_A__c, Inspect_QTY_B__c,
                Inspect_QTY_C__c, Inspect_QTY_D__c, To_DEF_Order__c,
                Inbound_QTY__c, 
                (
                    SELECT ContentDocumentId, ContentDocument.FileExtension, 
                    ContentDocument.Description, ContentDocument.Owner.Name
                    FROM ContentDocumentLinks WHERE ContentDocument.Owner.Profile.Name IN:pnames
                )
            FROM RTV_Order__c
            WHERE Status__c IN ('Insp Confirmed', 'Inbound')
            AND Return_Summary__c = :this.summaryId FOR UPDATE
        ];
        
        this.workOrdersIds = new Set<Id>();
        
        for (RTV_Order__c order: this.orders) {
            if (order.Status__c == 'Insp Confirmed') {
                this.workOrdersIds.add(order.Id);
            }
        }
        this.workOrdersCnt = workOrdersIds.Size();

    }
    
    /** 返回上一页 */
    public PageReference cancel(){
        PageReference returnPage = new PageReference('/' + this.summaryId);
        returnPage.setRedirect(true);
        return returnPage;  
    }
    
    /** 入库*/
    public void inbound() {
        try {
            if(String.isBlank(this.summary.LF_WH_Inbound_Comment__c)){
                ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.ERROR, '备注必填'));
                return;
            }

            if (String.isBlank(this.summary.Attach_User__c) || !this.summary.Attach_User__c.contains('LFWH')) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.ERROR, '附件必须上传'));
                return;
            }

            if(this.summary.Recall__c == false){
                this.isBatchLoading = true;
            }else {
                this.isLoading = true;
            }

            inboundAB();
            inboundD();
        } catch (Exception err) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.ERROR, err.getMessage()));
            this.isBatchLoading = false;
            this.isLoading = false;
        }
    }
    
    /** 入库A、B品 */
    public void inboundAB() {
        if(this.workOrdersIds.size() > 0){
            for(Id order:this.workOrdersIds){
                RTV_Summary_InboundAB_Batch batch = new RTV_Summary_InboundAB_Batch(order);
                this.job = new AsyncApexJob();
                this.job.Id = Database.executeBatch(batch, 100); // 一次处理100个item
            }
        }else {
            this.isBatchLoading = false;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.ERROR, '订单不存在，不能执行入库操作！'));
        }

        // List<RTV_Order_Item__c> upItems = new List<RTV_Order_Item__c>();
        
        // // 合计inboundQTY 
        // for (RTV_Order_Item__c item: [
        //     SELECT Id, Inspect_QTY_A__c, Inspect_QTY_B__c, Inspect_QTY_D__c
        //     FROM RTV_Order_Item__c
        //     WHERE RTV_Order__c IN :this.workOrdersIds
        // ]) {
        //     // 设置inboundQty
        //     RTV_Order_Item__c upItem = new RTV_Order_Item__c();
        //     upItem.Id = item.Id;
        //     upItem.Inbound_QTY__c =  item.Inspect_QTY_A__c + item.Inspect_QTY_B__c;
        //     upItems.add(upItem);
        // }
        // update upItems;
    }
    
    /** 入库C品 */
    public void inboundC() {
        if(String.isBlank(this.summary.LF_DELY_Inbound_Comment__c)){
            ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.ERROR, '备注必填'));
            return;
        }

        if (String.isBlank(this.summary.Attach_User__c) || !this.summary.Attach_User__c.contains('LFDELY')) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.ERROR, '附件必须上传'));
            return;
        }

        if(this.summary.LF_DELY_Inbound_Date__c == null){
            this.summary.LF_DELY_Inbound_Date__c = DateTime.now().date();
            // 自动完成关单
            this.summary.Status__c = 'Completed';
            update this.summary;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.CONFIRM, '入库成功'));
        }
    }
    
    /** 入库D品 */
    public void inboundD() {
        // D品转Defective
        if(this.summary.Recall__c == false){
            Date today = DateTime.now().date();
            List<RTV_DEF_Summary__c> defSummarys = [
                SELECT Id FROM RTV_DEF_Summary__c
                WHERE TakeBack_From_Date__c <= :today AND TakeBack_Till_Date__c >= :today AND Account_Group__c =:this.summary.Account_Group__c
            ];
            if(defSummarys.size() > 0){
                RTV_Summary_Inbound_ToDef_Batch batch = new RTV_Summary_Inbound_ToDef_Batch(this.summaryId);
                this.job = new AsyncApexJob();
                this.job.Id = Database.executeBatch(batch, 100); // 一次处理100个item
            }else {
                this.isBatchLoading = false;
                ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.ERROR, '您还未创建'+this.summary.Account_Group__r.Name+'  '+DateTime.now().format('MM')+'月的DEF Summary！'));
            }
        }
        //D品入库
        else {
            if(this.workOrdersIds.size() > 0){
                for(Id order:this.workOrdersIds){
                    RTV_Summary_InboundD_Batch batch = new RTV_Summary_InboundD_Batch(order);
                    this.job = new AsyncApexJob();
                    this.job.Id = Database.executeBatch(batch, 100); // 一次处理100个item
                 }
            }else {
                this.isBatchLoading = false;
                ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.ERROR, '订单不存在，不能执行入库操作！'));
            }
            // List<RTV_Order_Item__c> upItems = new List<RTV_Order_Item__c>();
        
            // // 合计inboundQTY 
            // for (RTV_Order_Item__c item: [
            //     SELECT Id, Inspect_QTY_A__c, Inspect_QTY_B__c, Inspect_QTY_D__c
            //     FROM RTV_Order_Item__c
            //     WHERE RTV_Order__c IN :this.workOrdersIds
            // ]) {
            //     // 设置inboundQty
            //     RTV_Order_Item__c upItem = new RTV_Order_Item__c();
            //     upItem.Id = item.Id;
            //     upItem.Inbound_QTY__c =  item.Inspect_QTY_A__c + item.Inspect_QTY_B__c + item.Inspect_QTY_D__c;
            //     upItems.add(upItem);
            // }
            // update upItems;

            inboundLFWH();
            this.isLoading = false;
        } 
    }
    
    /** 检查Batch结果 */
    public void isBatchEnd() {
        // 检查D品入库或CS计算ZDSI的batch结果
        this.job = [
            SELECT Id, Status, JobItemsProcessed, TotalJobItems, NumberOfErrors, CompletedDate, ExtendedStatus
            FROM AsyncApexJob WHERE Id = :this.job.Id LIMIT 1
        ];

        // 结束时
        if (this.job.CompletedDate != null) {
            this.isBatchLoading = false;
            // 错误信息
            if (!String.isBlank(job.ExtendedStatus)) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.ERROR, job.ExtendedStatus));
            } 
            // 成功时
            else {
                if (loginUser.isCS) {
                    initSapReport();
                } else if (loginUser.isLF){
                    inboundLFWH();
                } else if(loginUser.isAdmin) {
                    if (this.summary.LF_WH_Inbound_Date__c == null) {
                        inboundLFWH();
                    } else {
                        initSapReport();
                    }
                }
            }
        }
    }

    /** LF仓库入库完成 */
    public void inboundLFWH() {
        this.summary.LF_WH_Inbound_Date__c = DateTime.now().date();
        update this.summary;
        updateOrderStatus();
        this.loadPage();
        ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.CONFIRM, '入库成功'));
    }
    
    /** SAP初期值设定 */
    public void initSapReport() {
        // SAP空白固定值设定
        this.summary.Asian_Size__c = null;
        this.summary.UPC__c = null;
        this.summary.Contract_Number__c = null;
        this.summary.BU__c = null;
        this.summary.Retail_Value__c = null;
        this.summary.Order_Type__c = 'ZRE';
        this.summary.Purchase_Order_Type__c = 'EMAL';
        // 设置Return_Reason_Code 召回：120 残次：220
        this.summary.Return_Reason_Code__c = '120';
        this.summary.Condition_type__c = 'ZDSI';
        this.summary.Condition_Value_Currency__c = 'CNY';
        this.summary.Combine_DN__c = null;

        update this.summary;

        ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.CONFIRM, 'ZDSI完成'));
    }

    /** 最终入库完成，变更order的状态 */
    private void updateOrderStatus(){
        List<RTV_Order__c> updOrders = new List<RTV_Order__c>();
        
        for (RTV_Order__c order: this.orders) {
            if (order.Status__c == 'Insp Confirmed') {
                RTV_Order__c updOrd = new RTV_Order__c();
                updOrd.Id = order.Id;
                updOrd.Status__c = 'Inbound';
                updOrders.add(updOrd);
            }
        }
        if (!updOrders.isEmpty()) {
            update updOrders;
        }
    }
    
    /** 静态方法：计算job执行进度 */
    private static Integer getJobPercent(AsyncApexJob job) {
        if (job != null && job.TotalJobItems > 0) {
            return Integer.valueOf(job.JobItemsProcessed / job.TotalJobItems * 100.0);
        }
        return 0;
    }


    /** 上传附件*/
    public void upload() {
        // 检查input
        if (fileBody == null) {
            ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR, '请选择上传文件'));
            return;
        }

        try {
            this.isLoading = true;
            ContentVersion v = new ContentVersion();
            v.versionData = fileBody;
            v.title = fileName;
            v.pathOnClient = fileName;
            insert v;
            ContentVersion cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:v.Id LIMIT 1];
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.LinkedEntityId = summaryId;
            cdl.ContentDocumentId= cv.ContentDocumentId;
            cdl.ShareType= 'I';
            insert cdl;

            // 权限设置
            ContentDocument doc = [SELECT Id FROM ContentDocument WHERE Id= :cv.ContentDocumentId LIMIT 1];
            doc.SharingPrivacy = 'P';
            update doc;

            String attachuser;
            if (loginUser.isCS) {
                attachuser = 'CS';
                share2OtherUser(cv.ContentDocumentId, loginUser.Profiles_CS, 'V');
                //share2OtherUser(cv.ContentDocumentId, loginUser.Profiles_Admin, 'C');
            } else if (loginUser.isLF){
                if(this.summary.CS_Inbound_Date__c == null){
                    attachuser = 'LFWH';
                }else {
                    attachuser = 'LFDELY';
                    //share2OtherUser(cv.ContentDocumentId, loginUser.Profiles_WSL, 'V');
                }
                share2OtherUser(cv.ContentDocumentId, loginUser.Profiles_LF, 'V');
                //share2OtherUser(cv.ContentDocumentId, loginUser.Profiles_CS, 'V'); 
                //share2OtherUser(cv.ContentDocumentId, loginUser.Profiles_Admin, 'C');
        
            } else if(loginUser.isAdmin) {
                ContentDocument cd = [SELECT Id FROM ContentDocument WHERE Id= :cv.ContentDocumentId LIMIT 1];
                if(this.summary.LF_WH_Inbound_Date__c == null){
                    // LFWH
                    User user = [SELECT Id FROM User WHERE Profile.Name IN:loginUser.Profiles_LF LIMIT 1];
                    cd.OwnerId = user.Id;
                    attachuser = 'LFWH';
                    share2OtherUser(cv.ContentDocumentId, loginUser.Profiles_LF, 'V');
                    //share2OtherUser(cv.ContentDocumentId, loginUser.Profiles_CS, 'V');
                    //share2OtherUser(cv.ContentDocumentId, loginUser.Profiles_Admin, 'C');
                }else if(this.summary.CS_Inbound_Date__c == null){
                    // CS
                    User user = [SELECT Id FROM User WHERE Profile.Name IN:loginUser.Profiles_CS LIMIT 1];
                    cd.OwnerId = user.Id;
                    attachuser = 'CS';
                    share2OtherUser(cv.ContentDocumentId, loginUser.Profiles_CS, 'V');
                    //share2OtherUser(cv.ContentDocumentId, loginUser.Profiles_Admin, 'C');
                }else {
                    // LFDELY
                    User user = [SELECT Id FROM User WHERE Profile.Name IN:loginUser.Profiles_LF LIMIT 1];
                    cd.OwnerId = user.Id;
                    attachuser = 'LFDELY';
                    share2OtherUser(cv.ContentDocumentId, loginUser.Profiles_LF, 'V');
                    //share2OtherUser(cv.ContentDocumentId, loginUser.Profiles_CS, 'V');
                    //share2OtherUser(cv.ContentDocumentId, loginUser.Profiles_WSL, 'V');
                    //share2OtherUser(cv.ContentDocumentId, loginUser.Profiles_Admin, 'C');
                }
                // 管理员上传Owner变更处理
                update cd;
            }

            if(String.isBlank(this.summary.Attach_User__c)){
                this.summary.Attach_User__c = attachuser + ';';
            } else if (!this.summary.Attach_User__c.contains(attachuser)) {
                this.summary.Attach_User__c += attachuser + ';';
            }
            update summary;

            ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.CONFIRM, '上传成功'));

            this.loadPage();
            this.isLoading = false;

        } catch (Exception err) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.ERROR, err.getMessage()));
            this.isLoading = false;
        }
    }

    /** 分享给其他人 */
    private void share2OtherUser(Id id, List<String> pnames, String shareType){
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (User user : [SELECT Id FROM User WHERE Profile.Name IN:pnames AND Id !=:UserInfo.getUserId() AND IsActive = true]) {
            ContentDocumentLink cslink = new ContentDocumentLink();
            cslink.LinkedEntityId = user.Id;
            cslink.ContentDocumentId= id;
            cslink.ShareType= shareType;
            cslink.Visibility = 'AllUsers';
            links.add(cslink);
        }
        
        if(links.size() > 0) {
            insert links;
        }
    }

    /** 删除附件 */
    public void deleteAttach(){
        ContentDocument cd = [SELECT Id, Title FROM ContentDocument WHERE Id= :contentDocumentId LIMIT 1];
        delete cd;

        String attachuser = '';
        if (loginUser.isCS) {
            attachuser = 'CS;';
        } else if (loginUser.isLF){
            if(this.summary.CS_Inbound_Date__c == null){
                attachuser = 'LFWH;';
            }else {
                attachuser = 'LFDELY;';
            }
        } else if(loginUser.isAdmin) {
            if(this.summary.LF_WH_Inbound_Date__c == null){
                // LFWH
                attachuser = 'LFWH;';
            }else if(this.summary.CS_Inbound_Date__c == null){
                // CS
                attachuser = 'CS;';
            }else {
                // LFDELY
                attachuser = 'LFDELY;';
            }
        }

        if(!this.existAttach() && this.summary.Attach_User__c != null){
            this.summary.Attach_User__c = this.summary.Attach_User__c.replace(attachuser,'');
            update this.summary;
        }
        this.loadPage();
    }

    /** 上传C品附件*/
    public void ZDSIComputing() {
        try {
            this.isBatchLoading = true;

            // 设置Delivery Date
            this.summary.Requested_Delivery_Date__c = this.deliveryDate;
            // ZDSI计算
            List<ID> ids = new List<Id>();
            for (RTV_Order__c order: this.orders) {
                ids.add(order.Id);
            }
            RTV_OrderItem_ZDSI_Batch batch = new RTV_OrderItem_ZDSI_Batch(ids);
            this.job = new AsyncApexJob();
            this.job.Id = Database.executeBatch(batch, 1000);
        } catch (Exception err) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.ERROR, err.getMessage()));
            this.isBatchLoading = false;
        }
    }

    /** CS入库完成 */
    public void inboundCS() {
        if(String.isBlank(this.summary.CS_Inbound_Comment__c)){
            ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.ERROR, '备注必填'));
            return;
        }

        if (String.isBlank(this.summary.Attach_User__c) || !this.summary.Attach_User__c.contains('CS')) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.ERROR, '附件必须上传'));
            return;
        }

        // 当summary没有C品时
        if (this.summary.Inspect_QTY_C__c < 1) {
            this.summary.LF_DELY_Inbound_Date__c = DateTime.now().date();
            // 自动完成关单
            this.summary.Status__c = 'Completed';
        }
        this.summary.CS_Inbound_Date__c = DateTime.now().date();
        update this.summary;
        this.loadPage();
        ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.CONFIRM, '入库成功'));
    }

    /** 判断附件是否存在 */
    private Boolean existAttach(){
        String[] pnames = null;
        if(loginUser.isLF){
            pnames = new String[]{'RMS IDC LF'};
        }else if(loginUser.isCS){
            pnames = new String[]{'RMS CS'};
        }else if(loginUser.isAdmin){
            pnames = adminAttach;
            if(this.summary.CS_Inbound_Date__c == null){
                // CS
                pnames = new String[]{'RMS CS'};
            }else {
                // LF
                pnames = new String[]{'RMS IDC LF'};
            }
        }
        RTV_Summary__c sumObj = [
            SELECT Name,
            (
                SELECT ContentDocumentId, ContentDocument.Owner.Name
                FROM ContentDocumentLinks WHERE ContentDocument.Owner.Profile.Name IN:pnames
            ) 
            FROM RTV_Summary__c WHERE Id = :this.summaryId
        ];

        if(sumObj.ContentDocumentLinks.size() > 0){
            return true;
        }

        return false;
    }
}