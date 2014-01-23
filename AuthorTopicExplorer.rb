#coding: utf-8
require 'fileutils'

class AuthorTopicExplorer
  def initialize(dir_name, author_hash = Hash.new)
    @make_dir = dir_name #トピック分けを保存するディレクトリ名
    @author_hash = author_hash #トピック分けする筆者リスト
    @load_words_limit = 20 #読込む単語数
    @min_topics = 3 #最小トピック数
    @max_topics = 8 #最大トピック数
    @author_topic = "/Users/tabris2012/local/LDA-master/author_topic" #author_topicプログラムの場所
    @alpha = 0.1 #トピック解析のハイパーパラメータ
    @iter = 100 #トピック解析のイテレーション
    @lim = 100 #トピック解析の出力制限
    @cumulated_limit = 0.7 #分類確率が50%以上の分小数の、全体に対する割合の下限値
  end
  #フォルダ内の単語リストをロードしてマージ
  def load_author_list(folder_name)
    files = Dir.glob(folder_name + "/*.txt") #単語リストファイルを取得
    
    files.slice(0..-1).each_with_index do |filename, i|
      file = open(filename, "r") #ファイル読込み
      
      word_array = Array.new #単語リストを回収
  
      while line = file.gets
        word = line.split("\t") #タブで区切る
        word_array.push([word[0], word[1].to_i]) #単語と出現数を回収
      end
      
      filename = filename.split(/\.|\//)
      @author_hash[filename[-2]] = word_array
    end
  end
  #筆者リストから全単語を回収してtsv化
  def make_words_tsv(save_file)
    output_file = @make_dir + "/" + save_file + ".tsv" #出力ファイル名
    
    if !File.exist?(@make_dir) #フォルダが存在しなかったら作成
      Dir.mkdir(@make_dir)
    end
    
    output = open(output_file, "w") #出力ファイル展開

    restrain = open("restraining_words.txt", "r") #出力抑制単語
    restrain_array = Array.new
    #出力抑制単語回収
    while line = restrain.gets
      word = line.split("\t")
      restrain_array.push(word[0])
    end
    
    puts "tsv file writing..."

    @author_hash.each_with_index do |(author_name, word_array), i|
      print "\r#{i+1}"
      output_line = author_name #1単語目に筆者名
      limit_words = @load_words_limit
      limit_freq = 0
  
      word_array.each do |word, freq|
        if freq < limit_freq
          break #頻度を下回ったら抜ける
        end
    
        if word.length <3
          next #単語長が短かったら無視
        elsif restrain_array.include?(word)
          next #抑制単語なら無視
        end
    
        output_line += "\t" + word
        limit_words -=1
        
        if limit_words == 0
          limit_freq = freq        
        end
      end
  
      output.write(output_line + "\n")
    end
    
    output.close
    puts "\nDone."
  end
  #tsvファイルを元にトピック解析
  def topic_analysis(tsv_file)
    tsv_from = @make_dir + "/" + tsv_file
    
    (@min_topics..@max_topics).each do |topics|
      topic_dir = @make_dir + "/T#{topics}" #作成するフォルダ名
      
      if !File.exist?(topic_dir) #フォルダが存在しなかったら作成
        Dir.mkdir(topic_dir)
      end
      
      tsv_copy = topic_dir + "/" + tsv_file #コピー先tsvファイル
      FileUtils.copy_entry(tsv_from, tsv_copy) #ファイルコピー
      
      exec_arg = @author_topic + " " + tsv_copy + " #{@alpha} #{topics} #{@iter} #{@lim}"
      system(exec_arg) #author_topicを実行
    end
  end
  #トピック数ごとの文章の分類確率の累積度数分布から、最良トピックを推定する
  def topic_author_frequency(tsv_file)
    best_topics = @min_topics #最良トピック数を回収する
    puts "Best topic number searching..."
    
    (@min_topics..@max_topics).each do |topic_num|
      theta_file = @make_dir + "/T#{topic_num}/" + tsv_file + "_theta"
      output_file = @make_dir + "/T#{topic_num}/" + tsv_file + "_max_theta_hist.txt"

      theta_open = open(theta_file, "r");
      theta_list = theta_open.readlines #ファイルを全て読込み
      hist = Array.new(11){0} #確率分布を回収するヒストグラム変数
      topic_belongs = Array.new(topic_num){0} #トピックに属するauthor数を数える

      theta_list.each_with_index do |line, i|
        if i%topic_num ==0
          line_list = line.split("\t")
          theta_value = line_list[2].to_f #分類確率を取得
          theta_topic = line_list[1].to_i #分類されたトピック番号を取得
          hist[(theta_value*10).truncate] +=1 #対応する変数に頻度追加
          topic_belongs[theta_topic] +=1 #対応するトピック番号に頻度追加
        end
      end

      output = open(output_file, "w") #ヒストグラム出力
      output.write("theta\tnumbers\tcumulated %\n")
      accume_num = 0 #累積著者数
      total_num = theta_list.length.to_f/topic_num #著者数

      hist.reverse.each_with_index do |value, i|
        accume_num += value
        output.write("#{(1-i*0.1).round(1)}\t#{value}\t#{accume_num/total_num}\n")
        
        if i ==5 #分類確率50%以上
          if (accume_num/total_num) > @cumulated_limit #下限値以上なら
            best_topics = topic_num #トピック数を回収
          end          
        end
      end
      #次にトピック分類数を出力
      output.write("\ntopic\tnumbers\n")
  
      topic_belongs.each_with_index do |value, i|
        output.write("#{i}\t#{value}\n")
      end
  
      output.write("total\t#{total_num.to_i}\n")
    end
    
    return best_topics #トピック番号を返却
  end
end

#以下エントリーポイント
if __FILE__==$0
  author_topic = AuthorTopicExplorer.new("search001")
  author_topic.load_author_list("WordScore")
  author_topic.make_words_tsv("search001")
  author_topic.topic_analysis("search001.tsv")
  puts author_topic.topic_author_frequency("search001.tsv")
end

