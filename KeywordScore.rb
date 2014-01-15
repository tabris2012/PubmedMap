#coding: utf-8
require '../WebAbstract/GENIA_controller'

class KeywordScore
  def initialize()
    @genia = GENIA_controller.new("../GENIA_server")
  end
  
  def getScore(doc_hash, poster_num) #文献リストから単語スコアを返却
    doc_word = Hash.new #文献リストの総合単語スコアを回収
    freq_array = Array.new #文献ごとの出現頻度ハッシュを回収
    
    doc_hash.each do |title, abst|
      freq_array.push(getFreq(title+"\n"+abst))
    end
=begin
    freq_array.each do |hash|
      hash.each do |word, freq|
        if doc_word.include?(word) #既に追加済なら
          doc_word[word][0] += freq #出現数を加算
          doc_word[word][1] += 1 #出現論文数を加算
        else #新規登録
          doc_word[word] = [freq, 1] #出現数と出現論文数
        end
      end
    end
    
    doc_word.each do |word, array| #出現数と論文数をかける
      doc_word[word] = doc_word[word][0] * doc_word[word][1]
    end
   
    doc_word = doc_word.sort{|a,b| b[1] <=> a[1]}
    dump_doc_word(doc_word, poster_num)
=end
  end
  
  def getAbstScore(doc_hash, poster_num) #ポスターアブストから単語スコアを返却
    doc_word = Hash.new #文献リストの総合単語スコアを回収
    freq_array = Array.new #文献ごとの出現頻度ハッシュを回収
    
    doc_hash.each do |title, abst|
      freq_array.push(getFreq(title+"\n"+abst))
    end
    #最後の単語リストはポスターのアブストのもの
    freq_array.last.each do |word, freq|
      doc_word[word] = [freq, 1]  #そのまま登録
    end
    #最後以外からアブストの単語リストの重みづけを行う
    freq_array.slice(0..-2).each do |hash|
      hash.each do |word, freq|
        if doc_word.include?(word) #アブストに存在する単語なら
          doc_word[word][0] += freq #出現数を加算
          doc_word[word][1] += 1 #出現論文数を加算
        end #存在しない場合は何もしない
      end
    end
    
    doc_word.each do |word, array| #出現数と論文数をかける
      doc_word[word] = doc_word[word][0] * doc_word[word][1]
    end
   
    doc_word = doc_word.sort{|a,b| b[1] <=> a[1]} #降順
    damp_doc_word(doc_word, poster_num) #ファイル出力
  end
  
  def dump_doc_word(doc_word, filename)
    file = open(filename, "w")
    
    doc_word.each do |word, score|
      file.write(word + "\t" + score.to_s + "\n")
    end
  end
  
  def getFreq(document) #英文から単語数計算
    result =  @genia.tagger_sentence(document).chomp
    word_list = Hash.new #単語出現数を数えるハッシュ
    
    result.each_line do |line|
      #puts line
      elements = line.split(/\t/) #タブ区切りにする
      
      if elements[2] =~ /^NN/ #名詞を回収
        word = elements[1].downcase #小文字に直す
        
        if elements[4] != "O\n" #生命科学用語なら
          point = 2
        else
          point = 1
        end
        
        if word_list.include?(word) #既に追加済なら
          word_list[word] += point
        else #新規登録
          word_list[word] = point
        end
      end
    end
    
    return word_list #単語数ハッシュを返却
  end
end

#以下エントリーポイント
if __FILE__==$0
  key_score = KeywordScore.new()
  file = open("Abstract/1S8I-1.txt");
  i = 0;
  
  while i < 9
    text = file.readline;
    i += 1
  end
  
  text = file.readline;
  text += file.readline;
  key_score.getFreq(text);
end
