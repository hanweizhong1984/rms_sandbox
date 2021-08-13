/** 将Takeback的item转为defect的batch */
public class RTV_Summary_Inbound_ToDef_Batch implements Database.Batchable<SObject>, Database.Stateful{
    
    /** 参数：目标summaryId */
    private final Id summaryId;

    // order的recordtypes
    private final Map<String, RecordType> allTypes = RMS_CommonUtil.getRecordTypes('RTV_Order__c');
    // item的recordtypes
    private final Map<String, RecordType> itemTypes = RMS_CommonUtil.getRecordTypes('RTV_Order_Item__c');
    
    // key: defSummaryId
    private Map<Id, List<RTV_Order__c>> defSumOrders = new Map<Id, List<RTV_Order__c>>();
    
    // 合计各个lfOrderCode的D品合计
    private Map<String, Decimal> lfOrder_InspQty_D = new Map<String, Decimal>();
    
    /** 构造方法 */
    public RTV_Summary_Inbound_ToDef_Batch(Id summaryId) {
        this.summaryId = summaryId;
    }
    
    /** 开始 */
    public Database.QueryLocator start(Database.BatchableContext info){
        
        // 创建defsummary的order
        this.createDefSummarysOrders();
        
        // 检索Takeback的order的item，执行batch
        return Database.getQueryLocator([
            SELECT Name, LF_Order_Auth_Code__c,
                BU_2__c, Material_Code__c, SKU_Size_US__c, Season_Code_CN__c, 
                Product__c, TradeTerm__c, MSRP__c, NET__c, SKU_BU__c, 
                Inspect_QTY_A__c, Inspect_QTY_B__c, Inspect_QTY_C__c, Inspect_QTY_D__c,
                Selling_Unit_Price__c, Selling_Type__c, Selling_Season__c, SP_TaxRate__c,
                RTV_Order__r.To_DEF_Order__c,
                RTV_Order__r.Sold_To__r.SAP_Customer_Name__c,
                RTV_Order__r.Sold_To__r.Sold_To_Name_CN__c,
                RTV_Order__r.Ship_To__c,
                (
                    SELECT Box_Code__c, Application_QTY__c FROM RTV_Order_Packings__r
                )
            FROM RTV_Order_Item__c 
            WHERE  Inspect_QTY_D__c > 0
            AND RTV_Order__r.To_DEF_Order__c != null
            AND RTV_Order__r.Status__c = 'Insp Confirmed'
            AND RTV_Order__r.Return_Summary__c = :this.summaryId
        ]);
    }
    
    /** 执行 */
    public void execute(Database.BatchableContext info, List<RTV_Order_Item__c> tbItems){
        List<RTV_Order_Item__c> newDefItems = new List<RTV_Order_Item__c>();
        List<RTV_Order_Item_DEF_Detail__c> newDefDetails = new List<RTV_Order_Item_DEF_Detail__c>();
        
        // 遍历takeback的item
        for (RTV_Order_Item__c item: tbItems) {
            
            // 遍历item的箱号信息（defective的item里有箱号，而takeback的item的箱号在packingDetail里）
            for (RTV_Order_Packing__c pkg: item.RTV_Order_Packings__r) {
                
                List<RTV_Order__c> orders = this.getOrders(item.RTV_Order__r.To_DEF_Order__c);
                if(orders.size() < 1){
                    continue;
                }
                RTV_Order__c defOrder = orders.get(0);
                // 添加defective.item
                RTV_Order_Item__c newItem = new RTV_Order_Item__c();
                newItem.BU_2__c = item.BU_2__c;
                newItem.Material_Code__c = item.Material_Code__c;
                newItem.SKU_Size_US__c = item.SKU_Size_US__c;
                newItem.Season_Code_CN__c = item.Season_Code_CN__c;
                newItem.Defective_Box_Code__c = pkg.Box_Code__c;
                
                // Product信息
                newItem.Product__c = item.Product__c;
                newItem.SKU_BU__c = item.SKU_BU__c;
                newItem.TradeTerm__c = item.TradeTerm__c;
                newItem.MSRP__c = item.MSRP__c;
                newItem.NET__c = item.NET__c;
                
                // Selling信息
                newItem.Selling_Type__c = item.Selling_Type__c;
                newItem.Selling_Unit_Price__c = item.Selling_Unit_Price__c;
                newItem.Selling_Season__c = item.Selling_Season__c;
                newItem.SP_TaxRate__c = item.SP_TaxRate__c;
                
                // 各种QTY = item.Inspect_QTY_D__c
                newItem.Application_QTY__c = item.Inspect_QTY_D__c;
                newItem.Inspect_QTY_D__c = item.Inspect_QTY_D__c;
                newItem.Inbound_QTY__c = item.Inspect_QTY_D__c;
                
                // Defective信息(退残理由为空)
                newItem.Defective_Source__c = '';
                newItem.Defective_Reason__c = '';
                newItem.IsMaterial__c = false;
                newItem.RecordTypeId = itemTypes.get('Defective Order Item').Id;
                
                // 设置唯一键
                Integer numFrom = newDefDetails.Size() + 1;
                Integer numTill = newDefDetails.Size() + Integer.valueOf(pkg.Application_QTY__c);
                newItem.UniqueKey__c = RMS_CommonUtil.item_getUniqueKeyDef(defOrder.Name, newItem, numFrom, numTill);
                newItem.Name = item.Name;
                newItem.RTV_Order__c = defOrder.Id;
                // System.debug('#### create item: ' + newItem.UniqueKey__c);
                
                // 把item拆分成qty=1的detail
                for (Integer qty=0; qty < newItem.Inspect_QTY_D__c; qty++) {
                    
                    // 创建defective明细
                    RTV_Order_Item_DEF_Detail__c def = new RTV_Order_Item_DEF_Detail__c();
                    def.Application_QTY__c = 1;
                    def.Actual_QTY__c = 1;
                    def.Acceptable_Return_QTY__c = 1;
                    
                    // packing信息
                    def.Order_Auth_Code__c = RMS_CommonUtil.order_getLFCode(defOrder.Name, newItem.BU_2__c);
                    def.BU_2__c = newItem.BU_2__c;
                    def.Customer_Abbreviation__c = item.RTV_Order__r.Sold_To__r.Sold_To_Name_CN__c;
                    def.Customer_Name__c = item.RTV_Order__r.Sold_To__r.Sold_To_Name_CN__c;
                    def.Defective_Source__c = '';
                    def.Defective_Reason__c = '';
        
                    // product信息
                    def.Material_Code__c = newItem.Material_Code__c;
                    def.SKU_Size_US__c = newItem.SKU_Size_US__c;
                    def.Sold_To__c = item.RTV_Order__r.Sold_To__c;
                    def.Ship_To__c = item.RTV_Order__r.Ship_To__c;
                    def.Season_Code_CN__c = newItem.Season_Code_CN__c;
                    
                    // 唯一信息
                    def.RTV_Order_Item__r = new RTV_Order_Item__c(UniqueKey__c=newItem.UniqueKey__c);
                    def.Detail_Number__c = newDefDetails.Size() + 1;
                    def.Name = def.Detail_Number__c.format();
                    
                    newDefDetails.add(def);
                }
                newDefItems.add(newItem);
                
                // 合计该LFOrder的qty
                Decimal qtyD = this.lfOrder_InspQty_D.get(item.LF_Order_Auth_Code__c);
                qtyD = (qtyD == null)? item.Inspect_QTY_D__c: (qtyD + item.Inspect_QTY_D__c);
                this.lfOrder_InspQty_D.put(item.LF_Order_Auth_Code__c, qtyD);
            }
        }
        upsert newDefItems;
        insert newDefDetails;
    }
    
    /** 创建defective */
    private void createDefSummarysOrders() {
        // ----------------------------------
        // 获取创建的defSummay
        // ----------------------------------
        Date today = DateTime.now().date();
        List<RTV_DEF_Summary__c> defSummarys = [
            SELECT Id, 
                Account_Group__c,
                TakeBack_From_Date__c,
                TakeBack_Till_Date__c
            FROM RTV_DEF_Summary__c
            WHERE TakeBack_From_Date__c <= :today AND TakeBack_Till_Date__c >= :today
        ];

        // ----------------------------------
        // 为有D品的order关联defSummary
        // ----------------------------------
        Map<Id, RTV_Order__c> tbOrders = new Map<ID, RTV_Order__c>([
            SELECT Id, Name, Inspect_QTY_D__c, Ship_To__c, Sold_To__c, Ship_To__r.Code_Add__c, Sold_To__r.Account_Group__c,
                OwnerId, Ship_To_Phone1__c, Ship_To_Phone2__c, Ship_To_Contact__c, Ship_To_Address__c, Earliest_Delivery_Date__c, Status__c,
                Insp_CS_Approve_Time__c
            FROM RTV_Order__c
            WHERE Inspect_QTY_D__c > 0
            AND To_DEF_Order__c = null
            AND Status__c = 'Insp Confirmed'
            AND Return_Summary__c = :this.summaryId
        ]);
        for (RTV_Order__c obj : tbOrders.values()) {
            // 更新Takeback.order: 关联defSummary.id
            for(RTV_DEF_Summary__c defobj : defSummarys){
                if(defobj.Account_Group__c == obj.Sold_To__r.Account_Group__c){
                    //生成对应RTV_Order
                    RTV_Order__c order = new RTV_Order__c();
                    order.RTV_DEF_Summary__c = defobj.Id;
                    order.From_TakeBack_Order__c = obj.Id;

                    order.OwnerId = obj.OwnerId;
                    order.Ship_To_Phone1__c = obj.Ship_To_Phone1__c;
                    order.Ship_To_Phone2__c = obj.Ship_To_Phone2__c;
                    order.Ship_To_Contact__c = obj.Ship_To_Contact__c;
                    order.Ship_To_Address__c = obj.Ship_To_Address__c;
                    order.Earliest_Delivery_Date__c = obj.Earliest_Delivery_Date__c;

                    order.name = 'DEF' + obj.Name.substring(3);
                    order.Ship_To__c = obj.Ship_To__c;
                    order.Sold_To__c = obj.Sold_To__c;
                    order.Ship_To_Address__c = obj.Ship_To__r.Code_Add__c;
                    order.RecordTypeId = allTypes.get('RTV Defective Insp Wait Approval').Id;
                    order.Order_Type__c = 'RTV Defective';
                    order.Status__c = 'Insp Wait Approval';
                    order.Actual_Date_Of_WSL_Inbound__c = Date.today();
                    order.Insp_CS_Approve_Time__c = obj.Insp_CS_Approve_Time__c;

                    if(this.defSumOrders.containsKey(defobj.Id)){
                        this.defSumOrders.get(defobj.Id).add(order);
                    } else {
                        this.defSumOrders.put(defobj.Id, new List<RTV_Order__c>{order});
                    }
                }
            }
        }

        insert this.getOrders(null);

        // 修改To DEF ID
        List<RTV_Order__c> updateTBOrders = new List<RTV_Order__c>();
        for(Id defsumId : this.defSumOrders.keySet()){
            for (RTV_Order__c obj : this.defSumOrders.get(defsumId)) {
                if(tbOrders.containsKey(obj.From_TakeBack_Order__c)){
                    RTV_Order__c tbord = new RTV_Order__c();
                    tbord.Id = obj.From_TakeBack_Order__c;
                    tbord.To_DEF_Order__c = obj.Id;
                    updateTBOrders.add(tbord);
                }
            }
        }
        update updateTBOrders;
    }
    
    /** 因为没有走post to lf流程，所以需要手动创建order下的lfOrder */
    private void createDefectiveLfOrder() {
        List<RTV_LF_Order__c> newLfOrders = new List<RTV_LF_Order__c>();
    
        // 检索Takeback的lforder
        for (RTV_LF_Order__c tbLfO: [
            SELECT Name, LF_Order_Auth_Code__c, BU_2__c,
                Delivery_QTY__c, Delivery_Diff_QTY__c, Delivery_Date__c,
                Box_QTY__c, Box_Size__c, Arrival_Date__c,
                RTV_Order__r.To_DEF_Order__c
            FROM RTV_LF_Order__c
            WHERE LF_Order_Auth_Code__c IN :this.lfOrder_InspQty_D.KeySet()
        ]) {
            // 获取对应的defective.order
            List<RTV_Order__c> orders = this.getOrders(tbLfO.RTV_Order__r.To_DEF_Order__c);
            if(orders.size() < 1){
                continue;
            }
            RTV_Order__c defOrder = orders.get(0);
            // 创建新的lforder
            RTV_LF_Order__c newLfO = new RTV_LF_Order__c();
            newLfO.Name = RMS_CommonUtil.order_getLFCode(defOrder.Name, tbLfO.BU_2__c);
            newLfO.LF_Order_Auth_Code__c = newLfO.Name;
            newLfO.RTV_Order__c = defOrder.Id;
            newLfO.BU_2__c = tbLfO.BU_2__c;
            
            // 设置delivery信息
            newLfO.Box_QTY__c = tbLfO.Box_QTY__c;
            newLfO.Box_Size__c = tbLfO.Box_Size__c;
            newLfO.Arrival_Date__c = tbLfO.Arrival_Date__c;
            newLfO.Delivery_Date__c = tbLfO.Delivery_Date__c;
            
            // 设置qty=D品qty
            newLfO.Application_QTY__c = this.lfOrder_InspQty_D.get(tbLfO.LF_Order_Auth_Code__c);
            newLfO.Delivery_QTY__c = newLfO.Delivery_QTY__c;
            newLfO.Delivery_Diff_QTY__c = newLfO.Delivery_Diff_QTY__c;
            
            newLfOrders.add(newLfO);
            
        }
        upsert newLfOrders;
    }

    /** 获取新增Orders */
    private List<RTV_Order__c> getOrders(ID Id){
        List<RTV_Order__c> orders = new List<RTV_Order__c>();

        if(id == null){
            for (List<RTV_Order__c> objs: this.defSumOrders.values()) {
                orders.addAll(objs);
            }
        } else {
            for (List<RTV_Order__c> objs: this.defSumOrders.values()) {
                for (RTV_Order__c obj : objs) {
                    if(obj.Id == Id){
                        orders.add(obj);
                        break;
                    }
                }

                if(orders.size() == 1){
                    break;
                }
            }
        }

        return orders;
    }
    
    /** 结束 */
    public void finish(Database.BatchableContext info){
        try {
            // 抛出job执行时统计的异常
            AsyncApexJob job = [SELECT ExtendedStatus FROM AsyncApexJob WHERE Id = :info.getJobId() LIMIT 1];
            if (!String.isEmpty(job.ExtendedStatus)) {
                throw new RMS_CommonUtil.RMSException(job.ExtendedStatus);
            }
            
            // 创建order下的lfOrder
            this.createDefectiveLfOrder();
        } 
        // 失败时删除数据
        catch (Exception err) {
            List<ID> ids = new List<ID>();
            for (List<RTV_Order__c> objs: this.defSumOrders.values()) {
                for (RTV_Order__c obj : objs) {
                    ids.add(obj.Id);
                }
            }

            delete [SELECT Id FROM RTV_LF_Order__c WHERE RTV_Order__c IN :ids];
            delete [SELECT Id FROM RTV_Order__c WHERE Id IN :ids];
        }
    }
    
}