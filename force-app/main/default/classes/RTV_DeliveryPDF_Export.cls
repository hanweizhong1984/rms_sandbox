public with sharing  class RTV_DeliveryPDF_Export {
    /** url参数: summaryId */
    public String summaryId = ApexPages.currentPage().getParameters().get('summaryId');
    public List<RTV_LF_Order__c> results {get; set;}
    public Map<Id, List<RTV_LF_Order__c>> orderMap {get; set;}
    public Set<Id> orderIds {get; set;}
    public List<PDF_Extend> allOrders{get;set;}
    public List<PDF_Extend> orders{get;set;}
    public String printType {get; set;}
    public Boolean isOpening {get; set;}
    RMS_CommonUtil.LoginUserInfo loginUser = new RMS_CommonUtil.LoginUserInfo();
    
    public RTV_DeliveryPDF_Export() {
        this.isOpening = true;
        if (this.summaryId != null) {
            this.results = [
                SELECT BU_2__c, Application_Box_QTY__c, 
                    Application_QTY__c, 
                    LF_Order_Auth_Code__c,
                    RTV_Order__r.Order_Auth_Code__c, 
                    RTV_Order__r.Earliest_Delivery_Date__c, 
                    RTV_Order__r.Ship_To__r.Sold_To_Code__r.Sold_To_Name_CN__c, 
                    RTV_Order__r.Ship_To__r.Province__c, 
                    RTV_Order__r.Ship_To__r.City__c, 
                    RTV_Order__r.Ship_To_Contact__c, 
                    RTV_Order__r.Ship_To_Phone1__c, 
                    RTV_Order__r.Ship_To_Phone2__c, 
                    RTV_Order__r.Ship_To_Address__c, 
                    RTV_Order__r.Ship_To__r.Sold_To_Code__r.Name, 
                    RTV_Order__r.Ship_To__r.Name,
                    RTV_Order__r.Have_Read_Delivery_Report__c,
                    RTV_Order__r.RTV_DEF_Summary__c
                FROM RTV_LF_Order__c
                WHERE (RTV_Order__r.Return_Summary__c = :this.summaryId 
                     OR RTV_Order__r.RTV_DEF_Summary__c = :this.summaryId)
                AND RTV_Order__r.Status__c IN ('POST to LF')
            ];

            // Id 是orderID
            this.orderMap = new Map<Id, List<RTV_LF_Order__c>>();
            for (RTV_LF_Order__c lforder : this.results) {
                if(this.orderMap.containsKey(lforder.RTV_Order__c)){
                    this.orderMap.get(lforder.RTV_Order__c).add(lforder);
                }else {
                    this.orderMap.put(lforder.RTV_Order__c, new List<RTV_LF_Order__c>{lforder});
                }
            }
 
            this.orderIds = this.orderMap.keySet();
            this.allOrders = new List<PDF_Extend>();
            for(Id id:this.orderMap.keySet()){
                PDF_Extend order = new PDF_Extend();
                order.shiptoCode=orderMap.get(id).get(0).RTV_Order__r.Ship_To__r.Name;
                order.Order_Auth_Code=orderMap.get(id).get(0).RTV_Order__r.Order_Auth_Code__c;
                order.Sold_To_Name=orderMap.get(id).get(0).RTV_Order__r.Ship_To__r.Sold_To_Code__r.Sold_To_Name_CN__c;
                order.Province=orderMap.get(id).get(0).RTV_Order__r.Ship_To__r.Province__c;
                order.City=orderMap.get(id).get(0).RTV_Order__r.Ship_To__r.City__c;
                order.Ship_To_Address=orderMap.get(id).get(0).RTV_Order__r.Ship_To_Address__c;
                order.Earliest_Delivery_Date=orderMap.get(id).get(0).RTV_Order__r.Earliest_Delivery_Date__c;
                order.Ship_To_Contact=orderMap.get(id).get(0).RTV_Order__r.Ship_To_Contact__c;
                order.Ship_To_Phone1=orderMap.get(id).get(0).RTV_Order__r.Ship_To_Phone1__c;
                order.Ship_To_Phone2=orderMap.get(id).get(0).RTV_Order__r.Ship_To_Phone2__c;
                if(orderMap.get(id).get(0).RTV_Order__r.RTV_DEF_Summary__c!=null){
                    order.orderType='DEF';
                }else{
                    order.orderType='TB';
                }
                order.lforders=orderMap.get(id);
                order.boxTotal=0;
                order.goodsTotal=0;
                order.HaveReadDelivery=orderMap.get(id).get(0).RTV_Order__r.Have_Read_Delivery_Report__c;
                for(RTV_LF_Order__c lforder : orderMap.get(id)){
                    if(lforder.Application_Box_QTY__c!=null){
                        order.boxTotal+=lforder.Application_Box_QTY__c;
                    }
                    if(lforder.Application_QTY__c!=null){
                        order.goodsTotal+=lforder.Application_QTY__c;
                    }
                }
                this.allOrders.add(order);
            }
        }
    }
    // 更新Order的'提货信息已阅'Flag
    public void updateHaveReadDelivery() {
        // 只有lf下载时更新已阅
        if (loginUser.isLF == false && !Test.isRunningTest()) {
            return;
        }
        // 待更新order
        Map<Id, RTV_Order__c> updOrders = new Map<Id, RTV_Order__c>();
        
        // 遍历lfOrder
        for (RTV_LF_Order__c lfO: this.results) {
            // 修改关联order的flag
            if (lfO.RTV_Order__r.Have_Read_Delivery_Report__c == false) {
                RTV_Order__c updO = new RTV_Order__c();
                updO.Id = lfO.RTV_Order__r.Id;
                updO.Have_Read_Delivery_Report__c = true;
                updOrders.put(updO.Id, updO);
            }
        }
        // 更新order
        if (updOrders.size() > 0) {
            update updOrders.values();
        }
    }

    public PageReference test() {
        this.isOpening = false;
        this.orders = new List<PDF_Extend>();
        // 已阅
        if(printType == 'Have Read'){
            for (PDF_Extend order : this.allOrders) {
                if(order.HaveReadDelivery==true){
                    this.orders.add(order);
                }
            }
        }
        else if(printType == 'Not Read'){
            for (PDF_Extend order : this.allOrders) {
                if(order.HaveReadDelivery==false){
                    this.orders.add(order);
                }
            }
        }
        else {
            this.orders =this.allOrders;
        }

        return null;
    }

    public List<SelectOption> getItems() {
        List<SelectOption> options = new List<SelectOption>(); 
        options.add(new SelectOption('ALL','全部')); 
        options.add(new SelectOption('Have Read','已通知'));
        options.add(new SelectOption('Not Read','未通知'));
        return options; 
    }
    
    class PDF_Extend {
        public String shiptoCode{get;set;}
        public String Order_Auth_Code{get;set;}
        public String Sold_To_Name{get;set;}
        public String Province{get;set;}
        public String City{get;set;}
        public String Ship_To_Address{get;set;}
        public Date Earliest_Delivery_Date{get;set;}
        public String Ship_To_Contact{get;set;}
        public String Ship_To_Phone1{get;set;}
        public String Ship_To_Phone2{get;set;}
        public List<RTV_LF_Order__c> lforders{get;set;}
        public Decimal boxTotal{get;set;}
        public Decimal goodsTotal{get;set;}
        public Boolean HaveReadDelivery{get;set;}
        public String orderType{get;set;}
     }
    
}