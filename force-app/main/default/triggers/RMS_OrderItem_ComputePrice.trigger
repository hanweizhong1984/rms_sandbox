/** 
 * 当 Selling_Util_Price 或 Inspect_QTY 变更时：计算 Inspect_Amount__c
 */ 
trigger RMS_OrderItem_ComputePrice on RTV_Order_Item__c (before insert, before update, after update) {
    // --------------------------------------
    // 更新前，检查item的SellingPrice，赋值InspectAmount
    // --------------------------------------
    if (Trigger.isBefore) {
        // 当前税率
        Decimal nowTaxRate = ConverseRMS__c.getOrgDefaults().TaxRate__c;
        nowTaxRate = nowTaxRate != null? nowTaxRate: 1.0;
        
        // Item.RecordType
        Map<String, RecordType> itemTypes;
        
        // 查找inspect或selling变更的item
        for (RTV_Order_Item__c item: Trigger.new) {
            Boolean isInspChanged = false;
            // --新增时 (包括TB转DEF时新增的Item)
            if (Trigger.isInsert) {
                if (item.Selling_Unit_Price__c != null) {
                    isInspChanged = true;
                }
            }
            // --变更时
            else if (Trigger.isUpdate &&item.IsPreInbound__c==false) {
                RTV_Order_Item__c itemOld = Trigger.oldMap.get(item.Id);
                if (item.Selling_Unit_Price__c != itemOld.Selling_Unit_Price__c
                    || item.SP_TaxRate__c != itemOld.SP_TaxRate__c
                    || item.Inspect_QTY_A__c != itemOld.Inspect_QTY_A__c
                    || item.Inspect_QTY_B__c != itemOld.Inspect_QTY_B__c
                    || item.Inspect_QTY_D__c != itemOld.Inspect_QTY_D__c
                    || item.Selling_Type__c != itemOld.Selling_Type__c
                    || item.Recall__c != itemOld.Recall__c
                ) {
                    isInspChanged = true;
                }
                // ABD品有数量时，检查SellingPrice
                if (item.Inspect_QTY_A__c > 0 || item.Inspect_QTY_B__c > 0 || item.Inspect_QTY_D__c > 0) {
                    if((item.Selling_Type__c != itemOld.Selling_Type__c) || (item.Selling_Unit_Price__c != itemOld.Selling_Unit_Price__c) || item.SP_TaxRate__c != itemOld.SP_TaxRate__c)
                    {   
                        // SellingType有值时，SellingPrice必须为0
                        if(item.Selling_Unit_Price__c != null && item.Selling_Type__c != null && item.Selling_Unit_Price__c != 0)
                        {
                            item.addError('When Selling Type is not null, price cannot be set');
                        }
                        // SellingType为空时，SellingPrice不能为0
                        if((item.Selling_Unit_Price__c == null || item.Selling_Unit_Price__c == 0) && item.Selling_Type__c == null)
                        {
                            item.addError('Please fill in Selling Unit Price Or Selling Type');
                        }
                        // 当SellingPrice不为0，但SP_TaxRate为0时
                        if(item.Selling_Unit_Price__c > 0 && !(item.SP_TaxRate__c > 0))
                        {
                            item.addError('Please set the SP TaxRate, if the Selling Unit Price > 0. (item='+item.Name+')');
                        }
                    }
                }
            }
            // Selling或Insp变更时
            if (isInspChanged) {
                // 获取item的RecordTypes
                if (itemTypes == null) {
                    itemTypes = RMS_CommonUtil.getRecordTypes('RTV_Order_Item__c');
                }
                
                // sellingPrice赋0，避免null错误
                if (item.Selling_Unit_Price__c == null) {
                    item.Selling_Unit_Price__c = 0;
                }
                if (item.SP_TaxRate__c == null) {
                    item.SP_TaxRate__c = 0;
                }
                
                // 获取program.discount
                Decimal programDiscount = 1;
                if (item.Program_Discount__c != null && item.Program_Discount__c != 0) {
                    programDiscount = item.Program_Discount__c / 100;
                }
                
                // 初期化
                item.Inspect_Amount_A__c = 0;
                item.Inspect_Amount_B__c = 0;
                item.Inspect_Amount_D__c = 0;
                item.Inspect_Amount_A_inV__c = 0;
                item.Inspect_Amount_B_inV__c = 0;
                item.Inspect_Amount_D_inV__c = 0;
                
                // 存在SellingUnitPrice时计算金额
                if (item.Selling_Unit_Price__c > 0) {
                    // -----------------------------
                    // Takeback时
                    // -----------------------------
                    if (item.RTV_DEF_Summary__c == null) {
                        // B品的维修费
                        Decimal B_UpgradeCost_inv; 
                        Decimal B_UpgradeCost;     
                        // 在非Recall时计算B品的维修费
                        if(item.Recall__c == true) {
                            B_UpgradeCost_inv = 0;
                            B_UpgradeCost = 0;
                        } else {
                            //维修费(含税)
                            B_UpgradeCost_inv = item.BU_2__c.startsWith('F') ? 5.00: 3.00;
                            //维修费(除税)（按最新税率计算）
                            B_UpgradeCost = B_UpgradeCost_inv / nowTaxRate;
                            B_UpgradeCost = B_UpgradeCost.setScale(2, System.RoundingMode.HALF_UP);    
                        }
                        
                        // Amount(A) = Qty(A) * SellingPrice * Program.Discount
                        Decimal finalPriceA = (item.Selling_Unit_Price__c * programDiscount).setScale(2, System.RoundingMode.HALF_UP);
                        item.Inspect_Amount_A__c = (item.Inspect_QTY_A__c * finalPriceA).setScale(2, System.RoundingMode.HALF_UP);
                        item.Final_Price_A__c = finalPriceA;

                        // Amount(A)(含税) = Qty(A) * (SellingPrice * Program.Discount * SP_TaxRate)
                        Decimal finalPriceA_inV = (item.Selling_Unit_Price__c * programDiscount * item.SP_TaxRate__c).setScale(2, System.RoundingMode.HALF_UP);
                        item.Inspect_Amount_A_inV__c = (item.Inspect_QTY_A__c * finalPriceA_inV).setScale(2, System.RoundingMode.HALF_UP);
                        
                        // Amount(B) = Qty(B) * (SellingPrice * Program.Discount - 维护非(除税))
                        Decimal finalPriceB = (item.Selling_Unit_Price__c * programDiscount - B_UpgradeCost).setScale(2, System.RoundingMode.HALF_UP);
                        item.Inspect_Amount_B__c = (item.Inspect_QTY_B__c * finalPriceB).setScale(2, System.RoundingMode.HALF_UP);
                        item.Final_Price_B__c = finalPriceB;

                        // Amount(B)(含税) = Qty(B) * (SellingPrice * Program.Discount * SP_TaxRate - 维护费(含税))
                        Decimal finalPriceB_inV = (item.Selling_Unit_Price__c * programDiscount * item.SP_TaxRate__c - B_UpgradeCost_inV).setScale(2, System.RoundingMode.HALF_UP);
                        item.Inspect_Amount_B_inV__c = (item.Inspect_QTY_B__c * finalPriceB_inV).setScale(2, System.RoundingMode.HALF_UP);
                    }
                    // -----------------------------
                    // 订单为Defective时，或Takeback设置了Recall时
                    // -----------------------------
                    if(item.RTV_DEF_Summary__c != null || item.Recall__c == true) {
                        // Amount(D) = Qty(A) * SellingPrice
                        item.Inspect_Amount_D__c = (item.Inspect_QTY_D__c * item.Selling_Unit_Price__c).setScale(2, System.RoundingMode.HALF_UP);
                        item.Final_Price_D__c = item.Selling_Unit_Price__c;
                        
                        // Amount(B)(含税) = Qty(D) * (SellingPrice * SP_TaxRate)
                        Decimal finalPriceD_inV = (item.Selling_Unit_Price__c * item.SP_TaxRate__c).setScale(2, System.RoundingMode.HALF_UP);
                        item.Inspect_Amount_D_inV__c = (item.Inspect_QTY_D__c * finalPriceD_inV).setScale(2, System.RoundingMode.HALF_UP);
                    }
                    // 总退货金额
                    item.Actual_Amount__c = item.Inspect_Amount_A__c + item.Inspect_Amount_B__c + item.Inspect_Amount_D__c;
                    item.Actual_Amount_inV__c = item.Inspect_Amount_A_inV__c + item.Inspect_Amount_B_inV__c + item.Inspect_Amount_D_inV__c;
                }
            }
        }
    }
    // -----------------------------
    // 更新后，合计order下各SellingType的数量
    // -----------------------------
    else if(Trigger.isUpdate && Trigger.isAfter)
    {
        Set<Id> orderIds = new Set<Id>();
        List<RTV_Order__c> updOrders = new List<RTV_Order__c>();
        
        // 查找SellingType变更的orderId
        for (RTV_Order_Item__c item: Trigger.new) {
            RTV_Order_Item__c itemOld = Trigger.oldMap.get(item.Id);
            if(item.Selling_Type__c != itemOld.Selling_Type__c)
            {
                orderIds.add(item.RTV_Order__c);
            }
        }
        
        // 合计order下各SellingType的数量
        if (orderIds.size() > 0) {
            for (RTV_Order__c order: [
                SELECT ID, (SELECT Selling_Type__c FROM RTV_Order_Items__r)
                FROM RTV_Order__c WHERE ID IN: orderIds
            ]) {
                // 初期化=0
                RTV_Order__c updOrd = new RTV_Order__c();
                updOrd.Id = order.Id;
                updOrd.Not_Found_Count__c = 0;
                updOrd.TBD_Count__c = 0;
                
                // 合计各SellingType的item数量
                for(RTV_Order_Item__c item: order.RTV_Order_Items__r) {
                    if (item.Selling_Type__c != null && item.Selling_Type__c.startsWithIgnoreCase('t.b.d')) {
                        updOrd.TBD_Count__c ++;
                    }
                    if (item.Selling_Type__c != null && item.Selling_Type__c.replace(' ','').equalsIgnoreCase('notfound')){
                        updOrd.Not_Found_Count__c ++;
                    }
                }
                updOrders.add(updOrd);
            }
            update updOrders;
        }
    }
}