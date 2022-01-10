public class RMS_CommonUtil {
    /**
     * 检索目标objects的recordtype
     * @return map：{recordType.Name: recordType.id}}
     */
    public static Map<String, RecordType> getRecordTypes(String ObjectName) {
        Map<String, RecordType> result = new Map<String, RecordType>();
        
        // 检索recordtype
        List<RecordType> recordTypes = [
            SELECT Id, Name , SobjectType FROM RecordType
            WHERE SobjectType = :ObjectName];
        
        // 返回map
        for (RecordType rType: recordTypes) {
            result.put(rType.Name, rType);
        }
        return result;
    }
    
    /** 静态方法: summary.name(16位) = Program.Name(9位) - AccountGroup.Name(7位) */
    public static String summary_getName(String programCode, String accountGroupName) {
        
        String pgName = programCode != null? programCode.replace(' ', ''): '';
        pgName = pgName.length() > 9? pgName.substring(0, 9): pgName;
        
        String acgName = accountGroupName != null?  accountGroupName.replace(' ', ''): '';
        acgName = acgName.contains(')')? acgName.substring(acgName.indexOf(')') + 1): acgName;
        acgName = acgName.length() > 7? acgName.substring(0, 7): acgName;
        
        return pgName +'-'+ acgName;
    }
    
    /** 静态方法: order.授权码(30位) = Program.Name(9位) - AccountGroup.Name(7位) shipto.Name(6位) - 随机(6位) */
    public static String order_getCode(String programName, String accountGroupName, String shiptoName) {
        
        String shipName = shiptoName != null?  shiptoName.replace(' ', ''): '';
        shipName = shipName.length() > 6 ? shipName.substring(0, 6): shipName;
        
        Integer randomInt = (Math.random()*1000000).intValue();
        String randomStr = String.valueOf(randomInt).leftPad(6, '0');
        
        return summary_getName(programName, accountGroupName) + shiptoName +'-'+  randomStr;
    }
    
    /** 静态方法: lfOrder名称(退货授权码) = order(授权码) + BU（2位） */
    public static String order_getLFCode(String orderAuthCode, String bu2) {
        return orderAuthCode + bu2;
    }
    
    /** 静态方法：DEFProgram.授权码 */
    public static String defect_getCode() {
        Date today = System.today();
        return 'DEF' + today.year() + today.month() + ((Math.random()*9+1) * 100000).intValue();
    }
    
    /** 静态方法：DEFOrder.授权码= D{yyMMdd}{soldto.Code}{shipto.Code} */
    public static String defect_getCode(String soldtoCode, String shiptoCode) {
        String yymmdd = Datetime.now().format('yyMMdd');
        return 'D' + yymmdd + soldtoCode + shiptoCode;
    }
    
    /** 静态方法：获取item.Name（仅作为显示，不用于唯一判断） */
    public static String item_getName(RTV_Order_Item__c item) {
        return item.Material_Code__c 
            + '-' + item.SKU_Size_US__c 
            + (item.Season_Code_CN__c != null? '-' + item.Season_Code_CN__c: '');
    }
    
    /** 静态方法：（DTC）item.Name */
    public static String item_getNameDTC(RTV_Order_Item__c item) {
        return item.POS_SKU__c;
    }
    
    /** 静态方法：（DTC）item.UniqueKey */
    public static String item_getUniqueKeyDTC(String orderAuthCode, String posSku) {
        return orderAuthCode + '-' + posSku;
    }
    
    /** 静态方法：（DTC）item.POS_SKU */
    public static String item_getPosSku(RMS_Product__c pdt, String size) {
        String posSize = size;
        if(pdt.BU__c=='FT'){
        // size为数字时，需要补0到4位
        posSize = size.isNumeric()? size.leftPad(4, '0'): size; 
        }
        // pos_sku
        return pdt.SKU__c + posSize;
    }
    
    /** 静态方法：获取item.UniqueKey */
    public static String item_getUniqueKey(String orderAuthCode, RTV_Order_Item__c item) {
        return orderAuthCode
            + '-' + item.Material_Code__c
            + '-' + item.BU_2__c
            + '-' + item.SKU_Size_US__c
            + (item.Season_Code_CN__c != null? '-' + item.Season_Code_CN__c: '');
    }
    
    /** 静态方法：获取item.UniqueKey */
    public static String item_getUniqueKeyDef(String orderAuthCode, RTV_Order_Item__c item, Integer numFrom, Integer numTo) {
        return orderAuthCode + '-'
            + '-' + item.Material_Code__c
            + '-' + item.BU_2__c
            + '-' + item.SKU_Size_US__c
            + (item.Season_Code_CN__c != null? '-' + item.Season_Code_CN__c: '')
            + '-' + '(' + numFrom + '~' + numTo + ')';
    }
    
    /** 静态方法：判断item是否为'无实物退残' */
    public static Boolean item_Def_IsNoDelivery(String remark) {
        if ('无实物退残'.equals(remark) || (remark.length() == 20 && remark.startsWith('D'))) {
            return true;
        }
        return false;
    }
    
    /** 静态方法：判断item是否为'特批'退残 */
    public static Boolean item_Def_IsSepical(String remark) {
        return '特批'.equals(remark);
    }
    
    /** 
     * 静态方法：获取BU_2__c
     * @param Product__r.BUCN__c
     */
    public static String item_getBu2(String buCN) {
        String bu2;
        if (buCN != null && buCN.startsWithIgnoreCase('AP')) {
            bu2 = 'AP';
        } else if (buCN != null && buCN.startsWithIgnoreCase('AC')) {
            bu2 = 'AC';
        } else if (buCN != null && buCN.startsWithIgnoreCase('F')) {
            bu2 = 'FW';
        } else {
            throw new RMSException('The BU (' + buCN + ') is not start with one of following string: "AP", "AC", "F"');
        }
        return bu2;
    }
    
    /** 静态方法: 获取TradeTerm  (Takeback不考虑常青款) */
    public static Decimal item_getTradeTerm_TB(String Bu,  RMS_TradingTerm__c tradeTerm) {
        String fieldLabel;
        Decimal result;
        if (tradeTerm != null) {
            if (Bu.startsWith('A')) {
                fieldLabel = 'TT(APP/ACC)';
                result = tradeTerm.TT_APP_ACC__c;
            }
            if (Bu.startsWith('F')) {
                fieldLabel = 'TT(FW-Seasonal)';
                result = tradeTerm.TT_FW_Seasonal__c;
            }
        }
        return result;
    }
    
    /** 静态方法: 获取的TradeTerm （Defective考虑常青款） */
    public static Decimal item_getTradeTerm_DEF(String Bu, RMS_TradingTerm__c tradeTerm, Boolean isFwCore) {
        String fieldLabel;
        Decimal result;
        if (tradeTerm != null) {
            if (Bu.startsWith('A')) {
                fieldLabel = 'TT(APP/ACC)';
                result = tradeTerm.TT_APP_ACC__c;
            }
            else if (Bu.startsWith('F') && isFwCore) {
                fieldLabel = 'TT(FW-AS CORE)';
                result = tradeTerm.TT_FTW_EG__c;
            }
            else if (Bu.startsWith('F')) {
                fieldLabel = 'TT(FW-Seasonal)';
                result = tradeTerm.TT_FW_Seasonal__c;
            }
        }
        return result;
    }
    
    /**
     * 静态方法: 计算实际单价$NET = MSRP * TradingTerm / 税率 / 汇率 * Program.Discount
     */
    public static Double item_getNet(RMS_Product__c pdt, RTV_Program__c program, Decimal tradingTerm) {
        // 获取program.taxRate
        Double taxRate = program.TaxRate__c != null && program.TaxRate__c != 0 ? program.TaxRate__c : 1;
        // 获取program.exRate
        Double exRate = program.ExRate__c != null && program.ExRate__c != 0 ? program.ExRate__c : 1;
        // 获取program.discount(%)
        Double discount = program.Discount__c != null && program.Discount__c != 0 ? (program.Discount__c / 100) : 1;
        // 获取MSRP
        Decimal msrp = pdt.MSRP__c != null? pdt.MSRP__c: 0;
        
        // 实际NET
        return msrp * tradingTerm / taxRate / exRate * discount;
    }
    
    /**
     * 静态方法: 计算实际单价$NET = MSRP * TradingTerm / 税率 / 汇率
     */
    public static Double item_getNet(RMS_Product__c pdt, Decimal tradingTerm) {
        // 获取 Setup.TaxRate__c 和 ExRate__c
        ConverseRMS__c setup = ConverseRMS__c.getOrgDefaults();
        Decimal taxRate = setup.TaxRate__c != null && setup.TaxRate__c != 0 ? setup.TaxRate__c : 1;
        Decimal exRate = setup.ExRate__c != null && setup.ExRate__c != 0 ? setup.ExRate__c : 1;
        // 获取MSRP
        Decimal msrp = pdt.MSRP__c != null? pdt.MSRP__c: 0;
        
        // 实际NET
        return pdt.MSRP__c * tradingTerm / taxRate / exRate;
    }
    
    /**
     * str（yyyy-mm-dd）转 date
     */
    public static Date str2Date(String str) {
        List<String> ymd = str.split('/');
        if (ymd.Size() < 2) {
            ymd = str.split('-');
        }
        // 尝试 yyyy/MM/dd
        try {
            Integer year = Integer.valueOf(ymd[0]);
            Integer month = Integer.valueOf(ymd[1]);
            Integer day = Integer.valueOf(ymd[2]);
            Date res = Date.newInstance(year, month, day);
            if (year >= 1900 && month <= 12 && day <= 31) {
                return Date.newInstance(year, month, day);
            }
        } 
        catch (Exception err) {
        }
        // 尝试 MM/dd/yyyy
        try {
            Integer month = Integer.valueOf(ymd[0]);
            Integer day = Integer.valueOf(ymd[1]);
            Integer year = Integer.valueOf(ymd[2]);
            if (year >= 1900 && month <= 12 && day <= 31) {
                return Date.newInstance(year, month, day);
            }
        } catch (Exception err) {
        }
        throw new RMS_CommonUtil.RMSException('日期(' + str + ')的类型错误. 请尝试 "Year/Month/Day" 或 "Month/Day/Year" ');
    }
    
    /** String 转 Decimal */
    public static Decimal str2Decimal(String str, Decimal defVal) {
        try {
            return Decimal.valueOf(str.trim());
        } catch (Exception err) {
            return defVal;
        }
    }
    
    /**
     * VfPage里的addMessage方法（不显示超过1000行的message避免limit错误）
     */
    public static void pageAddMessage(ApexPages.Severity level, String msg) {
        if (ApexPages.getMessages().size() < 1000) {
            ApexPages.addMessage(new ApexPages.message(level, msg));
        }
    }
    
    /**
     * 将record共享给目标role及其下属
     */
    public static void shareToRoleSubordinates(Map<Id, Id> objAndRoleIds, SObjectType shareType, String accessLevel) {
        // 获取目标role的下属
        Map<Id, Group> roleAndSubs = new Map<Id, Group>();
        for (Group roleSub :[
            SELECT RelatedId, Type FROM Group 
            WHERE Type = 'RoleAndSubordinates' AND RelatedId IN :objAndRoleIds.values()
        ]) {
            roleAndSubs.put(roleSub.RelatedId, roleSub);
        }
        
        // 将record共享给其owner的role结构的下属
        List<SObject> shares = new List<SObject>();
        for (Id objId: objAndRoleIds.KeySet()) {
            Id roleId = objAndRoleIds.get(objId);
            Group roleSub = roleAndSubs.get(roleId);
            
            if (roleSub != null) {
                // 创建share
                SObject share = shareType.newSObject();
                share.put('ParentId', objId);
                share.put('UserOrGroupId', roleSub.Id);
                share.put('AccessLevel', accessLevel);
                shares.add(share);
            }
        }
        insert shares;
    }
    
    /**
     * 自定义异常
     */
    public class RMSException extends Exception {
    }
    
    /**
     * RMS用户类型
     */
    public class LoginUserInfo {
        public final Profile profile {get; set;}
        
        public final String[] Profiles_SysAdmin = new String[]{'系统管理员', 'System Administrator'};
        public final String[] Profiles_Admin = new String[]{'系统管理员', 'System Administrator', 'RMS Admin'};
        public final String[] Profiles_CS = new String[]{'RMS CS'};
        public final String[] Profiles_LF = new String[]{'RMS IDC LF'};
        public final String[] Profiles_WSL = new String[]{'RMS WSL HQ', 'RMS WSL Reg Branch', 'RMS WSL Sold To', 'RMS WSL Ship To', 'RMS WSL Ship To -Only DEF'};
        public final String[] Profiles_Soldto = new String[]{'RMS WSL Sold To'};
        public final String[] Profiles_Shipto = new String[]{'RMS WSL Ship To', 'RMS WSL Ship To -Only DEF'};
        public final String[] Profiles_DTC_Logistic = new String[]{'RMS CFS Logistic Confirm', 'RMS DIG Logistic Confirm'};
        public final String[] Profiles_DTC_ShipTo = new String[]{'RMS CFS Store', 'RMS DIG User'};
        
        public final String[] Profiles_WSL_BP = new String[]{'RMS WSL BP', 'RMS WSL DTC PLANNER'};
        public final String[] Profiles_CFS_BP = new String[]{'RMS CFS Planner', 'RMS WSL DTC PLANNER'};
        public final String[] Profiles_DIG_BP = new String[]{'RMS DIG Planner', 'RMS WSL DTC PLANNER'};
        
        // 管理员
        public final Boolean isSysAdmin {get; set;}
        public final Boolean isAdmin {get; set;}
        // CS
        public final Boolean isCS {get; set;}
        // LF
        public final Boolean isLF {get; set;}
        // 客户
        public final Boolean isWSL {get; set;}
        public final Boolean isSoldto {get; set;}
        public final Boolean isShipto {get; set;}
        public final Boolean isDtcLogistic {get; set;}
        public final Boolean isDtcShipTo {get; set;}
        public final Boolean isDtc {get; set;}
        // BP
        public final Boolean isWslBP {get; set;}
        public final Boolean isDtcCfsBP {get; set;}
        public final Boolean isDtcDigBP {get; set;}
        public final Boolean isDtcBP {get; set;}
        
        public LoginUserInfo() {
            this([SELECT Name FROM Profile WHERE Id=:UserInfo.getProfileId() LIMIT 1][0]);
        }
        public LoginUserInfo(Profile profile) {
            this.profile = profile;
            this.isSysAdmin = Profiles_SysAdmin.contains(profile.Name);
            this.isAdmin = Profiles_Admin.contains(profile.Name);
            this.isCS = Profiles_CS.contains(profile.Name);
            this.isLF = Profiles_LF.contains(profile.Name);
            this.isWSL = Profiles_WSL.contains(profile.Name);
            this.isSoldto = Profiles_Soldto.contains(profile.Name);
            this.isShipto = Profiles_Shipto.contains(profile.Name);
            this.isDtcLogistic = Profiles_DTC_Logistic.contains(profile.Name);
            this.isDtcShipTo = Profiles_DTC_ShipTo.contains(profile.Name);
            this.isDtc = isDtcLogistic || isDtcShipTo;
            
            this.isWslBP = Profiles_WSL_BP.contains(profile.Name);
            this.isDtcCfsBP = Profiles_CFS_BP.contains(profile.Name);
            this.isDtcDigBP = Profiles_DIG_BP.contains(profile.Name);
            this.isDtcBP = isDtcCfsBP || isDtcDigBP;
        }
    }
    
    /** 美码和亚码的转换表(BU仅限AP) */
    public static final Map<String, String> SIZE_US_2_ASIA_AP = new Map<String, String>{
        'XXXS'      => 'XXS',
        'XXS'       => 'XS',
        'XS'        => 'S',
        'S'         => 'M',
        'M'         => 'L',
        'L'         => 'XL',
        'XL'        => 'XXL',
        'XXL'       => 'XXXL',
        'XXXL'      => 'XXXXL',
        'XS/S'      => 'S/M',
        'S/M'       => 'M/L',
        'M/L'       => 'L/XL',
        'L/XL'      => 'XL/XXL',
        'XL/XXL'    => 'XXL/XXXL',
        'XXL/XXXL'  => 'XXXL/XXXXL',
        'XXXL/XXXXL'=> 'XXXXL/XXXXXL',
        'OS'        => 'OSFA',
        'I'         => 'XXS/XS',
        'II'        => 'S/M',
        'III'       => 'L/XL',
        'IIII'      => 'XXL3X'
    };
    /** 美码转亚码 */
    public static String size_Us2Asia(String usSize, String bu) {
        // 默认使用美码
        String result = usSize;
        
        // BU为"AP"时，亚码参考转换表
        if (bu.startsWith('AP')) {
            String mapSize = SIZE_US_2_ASIA_AP.get(usSize.toUpperCase());
            if (mapSize != null) {
                result = mapSize;
            }
        }
        return result == null? '': result;
    }
    /** 亚码转美码 */
    public static String size_Asia2Us(String asiaSize, String bu) {
        // 默认使用亚码
        String result = asiaSize;
        
        // BU为"AP"时，美码参考转换表
        if (bu.startsWith('AP')) {
            for (String key: SIZE_US_2_ASIA_AP.keySet()) {
                if (SIZE_US_2_ASIA_AP.get(key) == asiaSize.toUpperCase()) {
                    result = key;
                    break;
                }
            }
        }
        return result;
    }
    /** LF的美码转美码 */
    public static String size_lfUs2Us(String lfUsSize, String bu) {
        String result;
        // BU为"FW"时，LF的美码要除以10
        if (bu.startsWith('F')) {
            result = (str2Decimal(lfUsSize, 0) / 10).toPlainString();
        } else {
            if(bu.startsWith('AC')&&lfUsSize=='OS'){
                lfUsSize='OSFA';
            }
            result = lfUsSize;
        }
        return result == null? '': result;
    }
    
    /** 解析季节码(格式为20Q1) */
    public class SeasonCodeCN {
        public String SeasonCodeCN {get; set;}
        public Integer year {get; set;}
        public Integer quarter {get; set;}
        public Integer fiscalYear {get; set;}
        
        /** 构造方法 */
        public SeasonCodeCN(String seasonCodeCN) {
            if (!Pattern.matches('^[0-9]{2}Q[0-9]{1}$', seasonCodeCN)) {
                throw new RMS_CommonUtil.RMSException('季节码格式错误! 请输入正确如: "20Q1"');
            }
            this.seasonCodeCN = seasonCodeCN;
            // 年：2000 + 季节码前2位
            this.year = 2000 + Integer.valueOf(seasonCodeCN.substring(0, 2)); 
            // 季度：季节码最后1位
            this.quarter = Integer.valueOf(seasonCodeCN.substring(3));
            // 财政年度：季度3~4算作下一财年
            this.fiscalYear = this.quarter >= 3? this.year + 1: this.year;
        }
    }
    
}