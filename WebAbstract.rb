#coding: utf-8

require 'open-uri'
require 'addressable/uri'
require 'rexml/document'
require 'fileutils'

class WebAbstract
  def initialize()
    @esearchURL = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?"
    @efetchURL = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?"
    @eSummaryURL = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?"
    @useDB = "db=pubmed" #使用するデータベースを指定
    @abstractHash = Hash.new
    @maxIDs = 100 #取得する最大論文数
  end
  
  def reInit() #ハッシュをクリアして再初期化
    @abstractHash = Hash.new
  end
  
  def parseXMLtoAuthors(xml) #与えられたxmlからAuthor出現頻度を算出
    doc = REXML::Document.new(xml)
    author_hash = Hash.new
    
    doc.elements.each('PubmedArticleSet/PubmedArticle/MedlineCitation/Article') do |article|
      title = article.elements['ArticleTitle']
      author_list = article.elements['AuthorList']
      
      if (title and author_list) #どちらともnilでなければ
        author_list.elements.each('Author') do |author_part|
          if author_part.elements['LastName'] #フィールドが存在するなら
            last_name = author_part.elements['LastName'].text
          else
            next #無視して次へ
          end
          
          if author_part.elements['ForeName'] #フィールドが存在するなら
            fore_name = author_part.elements['ForeName'].text
          else
            fore_name = "" #存在しなければ空配列
          end
          
          author_name = last_name + ' ' + fore_name
          
          if author_hash.include?(author_name) #著者リストに存在するなら
            author_hash[author_name] += 1 #出現数を加算
          else
            author_hash[author_name] = 1 #著者を追加
          end
        end
      end
    end
    
    return author_hash
  end
  
  def webAuthorsByWords(search_words) #検索単語から筆者出現数ハッシュを作成
    id_array = getIDList(search_words)
    
    if id_array.empty? #空なら
      return Hash.new #空配列を返す
    end
    
    id_list = "id=" #ここに論文IDリストを回収
    id_num = id_array.length #id数
    
    id_array.each_with_index do |ids, i|
      id_list += ids
      
      if (i < (id_num-1)) #最後以外は
        id_list += ","
      end
    end
    
    api = @efetchURL + @useDB
    api += "&" + id_list + "&rettype=abstract"
    api = Addressable::URI.parse(api).normalize.to_s
    puts "Sending abstract request to Pubmed..."
    xml = open(api, 'User-Agent' => 'ruby').read
    puts "Got xml."
    dumpXML(xml, "testSearch")
    
    parseXMLtoAuthors(xml)
  end
  
  def webAbstractByAuthor(*authors) #筆者名からAbstractを取得
    id_array = getIDListByAuthor(*authors) #可変長で関数呼び回し

    if id_array.empty? #追加されていなければ
      if authors.length >1 #共著者が存在するなら
        id_array = getIDListByAuthor(authors[0]) #筆頭著者のみでIDリストを要求
      end
    end
    
    if id_array.empty? #それでも追加されていなければ
      return @abstractHash #空配列を返す
    end
    
    id_list = "id=" #ここに論文IDリストを回収
    id_num = id_array.length #id数
    
    id_array.each_with_index do |ids, i|
      id_list += ids
      
      if (i < (id_num-1)) #最後以外は
        id_list += ","
      end
    end
    
    api = @efetchURL + @useDB
    api += "&" + id_list + "&rettype=abstract"
    api = Addressable::URI.parse(api).normalize.to_s
    xml = open(api, 'User-Agent' => 'ruby').read
    #dumpXML(xml,authors[0])
    doc = REXML::Document.new(xml)
    
    doc.elements.each('PubmedArticleSet/PubmedArticle/MedlineCitation/Article') do |article|
      title = article.elements['ArticleTitle']
      abst = article.elements['Abstract/AbstractText']
      
      if (title and abst) #どちらともnilでなければ
        if (title.text and abst.text) #どちらともnilでなければ
          @abstractHash[title.text] = abst.text
        end
      end
    end
    
    return @abstractHash
  end
  
  def getIDListByAuthor(*authors) #筆者名で文献IDリストを取得するようクエリを作成
    search_query = '&field=author&term=' #著者フィールドを検索
    
    authors.each_with_index do |name, i|
      search_query += name.gsub(" ", "+") #空白を+に変換
      
      if (i < (authors.size - 1))
        search_query += '+AND+' #最後以外に追加
      end
    end
    
    getIDList(search_query)    
  end
  
  def getIDList(search_query) #クエリから文献IDリストを取得
    api = @esearchURL + @useDB #検索用URLの準備
    
    if search_query[0] != '&' #クエリフィールドが存在しなければ
      api += '&term='
    end
    
    api += search_query.gsub(" ", "+AND+") #空白をANDに変更
    api += '&retmax=' + @maxIDs.to_s #取得最大ID数を設定
    puts "Sending query request to PubMed..."
    api = Addressable::URI.parse(api).normalize.to_s
    xml = open(api, 'User-Agent' => 'ruby').read
    doc = REXML::Document.new(xml) #XMLパーサを作成
    id_array = Array.new #IDリストを回収
    
    doc.elements.each('eSearchResult/IdList/Id') do |id|
      id_array.push id.text #ID番号を回収
    end
    
    puts "Got " + id_array.length.to_s + " paper-IDs.\n"
    return id_array
  end
  
  def dumpAbstract(filename)
    if !File.exist?("Abstract")
      Dir.mkdir("Abstract")
    end
    
    file = open("./Abstract/" + filename + ".txt", "w")
    
    @abstractHash.each do |key, value|
      file.write(key + "\n" + value + "\n\n")
    end
  end
  
  def dumpXML(xml,filename)
    file = open("./data/" + filename + ".xml", "w")
    file.write(xml)
  end
end

#以下エントリーポイント
if __FILE__==$0
  abst = WebAbstract.new();
  abst.webAbstractByAuthor("Shinya Yamanaka", "Michiyo Koyanagi");
  abst.dumpAbstract("0001")
end
