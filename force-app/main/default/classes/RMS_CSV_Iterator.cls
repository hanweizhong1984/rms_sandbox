/** 
 * 读取csv的迭代器
 */
public with sharing class RMS_CSV_Iterator {
    
    /** 换行符 (同时支持'\r\n'和'\r'和'\n') */
    public String charRTN;
    
    /** UTF8-BOM */
    public static final String UTF8_BOM = '\uFEFF';
    public static final String UTF8_BOM_Hex = 'efbbbf';
    
    // 可选的csv编码 (SelectOption为VisualforcePage元素)
    public static final List<ApexPages.SelectOption> CHARSET_OPTIONS = new List<ApexPages.SelectOption>
    {
        new ApexPages.SelectOption('gb2312', 'GB2312'),
        new ApexPages.SelectOption('UTF-8', 'Unicode UTF-8')
    };
    
    /** csv上下文 */
    public String csvContents;
    private Integer csvLength;
    
    /** 当前行信息，执行next时变化 */
    public String line;
    public Integer lineIndex = 0;
    private Integer posStart = 0;
    private Integer posEnd = 0;
    
    /** 标题行 */
    public String headerLine = '';
    private List<String> title = new List<String>();
    
    /** 构造方法 */
    public RMS_CSV_Iterator(Blob csvBlob, String inCharset) {
        this.csvContents = RMS_CSV_Iterator.blobToString(csvBlob, inCharset);
        this.csvLength = csvContents.length();
        
        this.charRTN = 
            csvContents.indexOf('\r\n') > -1? '\r\n':
            csvContents.indexOf('\r') > -1? '\r': '\n';
    }
    
    /** 初期设置：获取并跳过标题行 */
    public void skipTitleLine() {
        // 固定第一行为空白行(可填备注)
        this.next();
        this.headerLine += this.line;
        // 第二行为标题
        if (this.next()) {
            this.title = this.getLineAsListLowCase();
            this.headerLine += this.charRTN + this.line;
        }
    }
    
    /** 初期设置：获取并跳过标题行，并检查标题内容 */
    public void skipTitleLine(String[] requireTitles) {
        this.skipTitleLineIgnoreCase(requireTitles);
    }
    
    /** 初期设置：获取并跳过标题行，并检查标题内容 */
    public void skipTitleLineIgnoreCase(String[] requireTitles) {
        List<String> missingTitles = new List<String>();
        
        // 检查第一行 (第一行可以是空白)
        this.next();
        this.title = this.getLineAsListLowCase();
        this.headerLine += this.line;
        missingTitles = this.getMissingTitle(requireTitles);
        
        // 检查第二行
        if (!missingTitles.isEmpty() && this.next()) {
            this.title = this.getLineAsListLowCase();
            this.headerLine += this.charRTN + this.line;
            List<String> misTits = this.getMissingTitle(requireTitles);
            
            // 取缺失列最少的
            if (misTits.size() < missingTitles.size()) {
                missingTitles = misTits;
            }
        }
        if (!missingTitles.isEmpty()) {
            throw new RMS_CsvException('Missing title from CSV: ' + missingTitles.toString());
        }
        System.debug('## 标题行= ' + this.title.toString());
    }
    
    /** 检查缺失的标题 */
    private List<String> getMissingTitle(String[] requireTitles) {
        List<String> missingTitles = new List<String>(requireTitles);
        
        // 遍历需要的标题
        for (String reqTit: requireTitles) {
            // csv中存在该标题，则从'缺失列'去除
            for (String tit: this.title) {
                if (tit.equalsIgnoreCase(reqTit)) {
                    missingTitles.remove(missingTitles.indexOf(reqTit));
                    break;
                }
            } 
        }
        return missingTitles;
    }
    
    /** 检索下一行 */
    public Boolean next() {
        if (this.posEnd >= this.csvLength) {
            return false;
        }
        
        // 获取下一个换行符的位置
        this.posEnd = this.csvContents.indexOf(this.charRTN, this.posStart);
        if (this.posEnd < 0) {
            this.posEnd = this.csvLength;
        }
        
        // 截取至下一个换行符
        this.line = this.csvContents.substring(this.posStart, this.posEnd).replaceAll('[\r\n]', '');
        
        this.posStart = this.posEnd + 1;
        this.lineIndex ++;
        
        // 当该行不为空白，且不仅仅只有逗号和空格时，返回true
        return !String.isBlank(this.line) && !this.line.containsOnly(', ');
    }
    
    /** 获取当前行为string */
    public String getLine() {
        return this.line;
    }
    
    /** 获取当前行为list */
    public List<String> getLineAsList() {
        List<String> fields = new List<String>();
        
        FieldIterator fieldIter = new FieldIterator(this.line);
        while (fieldIter.next()) {
            String field = fieldIter.getField();
            fields.add(field);
        }
        return fields;
    }
    
    /** 获取当前行为list */
    public List<String> getLineAsListLowCase() {
        List<String> fields = new List<String>();
        
        FieldIterator fieldIter = new FieldIterator(this.line);
        while (fieldIter.next()) {
            String field = fieldIter.getField();
            fields.add(field.toLowerCase());
        }
        return fields;
    }
    
    /** 获取当前行为map */
    public Map<String, String> getLineAsMap() {
        Map<String, String> tr = new Map<String, String>();
        try {
            Integer col = -1;
            FieldIterator fieldIter = new FieldIterator(this.line);
            while (fieldIter.next()) {
                col ++;
                String value = fieldIter.getField();
                tr.put(this.title[col], value);
            }
        } catch(Exception err) {
            throw new RMS_CommonUtil.RMSException('Csv格式错误！请保证明细与标题的列数一致.');
        }
        return tr;
    }
    
    /** blob转string(可指定编码类型) */
    public static String blobToString(Blob csvBlob, String inCharset){
        try {
            // 解析blob为16进制string
            String hex = EncodingUtil.convertToHex(csvBlob);
            
            // 删除utf-8前的BOM
            if (inCharset == 'UTF-8' && hex.startsWithIgnoreCase(UTF8_BOM_Hex)) {
                hex = hex.substring(6);
            }
            
            // 在每个16进制字节前加上"%"
            Final Integer bytesCount = hex.length() >> 1;
            String[] bytes = new String[bytesCount];
            for(Integer i = 0; i < bytesCount; ++i)
                bytes[i] =  hex.mid(i << 1, 2);
            String hexOk = '%' + String.join(bytes, '%');
            
            // 使用指定编码，解析有"%"的16进制string
            return EncodingUtil.urlDecode(hexOk, inCharset);
        } 
        catch (System.LimitException err) {
            throw new RMS_CommonUtil.RMSException('The CSV file is too large to parse its encoding.');
        }
    }
    
    /** 单行的信息 */
    public OneLineInfo getOneLineInfo() {
        return new OneLineInfo(this);
    }
    
    /**
     * 单行的信息(其中列标题默认是小写)
     */
    public virtual class OneLineInfo {
        private Map<String, String> tr;
        public String line;
        public Integer lineIndex;
        
        public OneLineInfo(RMS_CSV_Iterator iter) {
            this.tr = iter.getLineAsMap();
            this.line = iter.line;
            this.lineIndex = iter.lineIndex;
        }
        public String get(String key) {
            return tr.get(key.toLowerCase());
        }
        public Decimal getDecimal(String key, Integer defVal) {
            return RMS_CommonUtil.str2Decimal(this.get(key), defVal);
        }
        public void put(String key, String value) {
            tr.put(key.toLowerCase(), value);
        }
        public override String toString() {
            return tr.toString();
        }
        public List<String> values() {
            return tr.values();
        }
    }
    
    /** 
     * CSV单行中，各字段的迭代器 
     */
    public class FieldIterator {
        /** 正则表达式：\G(?:^|,)(?:"([^"]*+(?:""[^"]*+)*+)"|([^",]*+)) */
        private String LINE_REG = '\\G(?:^|,)(?:\"([^\"]*+(?:\"\"[^\"]*+)*+)\"|([^\",]*+))';
        
        private Matcher matcherMain;
        private Matcher matcherQuoto;
        
        /** 构造方法 */
        public FieldIterator(String line) {
            matcherMain = Pattern.compile(this.LINE_REG).matcher('');
            matcherQuoto = Pattern.compile(' \"\"').matcher('');
            
            matcherMain.reset(line.startsWith(',')? ' ' + line: line);
        }
        /** 下一个 */
        public Boolean next() {
            return matcherMain.find();
        }
        /** 获取字段 */
        public String getField() {
            String field;
            if (matcherMain.start(2) >= 0) {
                field = matcherMain.group(2);
            } else {
                field = matcherQuoto.reset(matcherMain.group(1)).replaceAll('\"');
            }
            return field;
        }
    }
    
    public class RMS_CsvException extends Exception {
    }

    // ----------------------给Batch用---------------------------------------------------------
    /**
     * (给Batch用)CSV可迭代对象
     */
    public class BatchIterable implements Iterable<RMS_CSV_Iterator.OneLineInfo> {
        RMS_CSV_Iterator csvIter;
        
        public BatchIterable(RMS_CSV_Iterator csvIter) {
            this.csvIter = csvIter;
        }
        
        public Iterator<RMS_CSV_Iterator.OneLineInfo> Iterator(){
            return new BatchIterator(csvIter);
        }
    }
    
    /**
     * (给Batch用)CSV迭代器
     */
    class BatchIterator implements Iterator<RMS_CSV_Iterator.OneLineInfo> {
        RMS_CSV_Iterator csvIter;
        
        public BatchIterator(RMS_CSV_Iterator csvIter){
            this.csvIter = csvIter;
        }
    
        public Boolean hasNext(){
            return this.csvIter.next();
        }
    
        public RMS_CSV_Iterator.OneLineInfo next(){ 
            return this.csvIter.getOneLineInfo();
        }
    }
    // ----------------------给Batch用---------------------------------------------------------
    
    /**
     * 使用方法1: 自己遍历每行
     *  xx = new RMS_CSV_Iterator();
     *  xx.skipTitleLine();
     *  while(xx.next) {
     *   xx.getLineAsMap();
     *  }
     * 
     * 使用方法2: 自己遍历每行每个字段
     *  xx = new RMS_CSV_Iterator();
     *  xx.skipTitleLine();
     *  while(xx.next) {
     *   ii = new RMS_CSV_Iterator.FieldIterator(xx.getLine());
     *   while (ii.next) {
     *      ii.getField();
     *   }
     *  }
     */
}