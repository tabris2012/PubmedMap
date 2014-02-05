# coding: utf-8
## トピックコアとの距離を描画する

require "rubygems"
require "gviz"

class TopicGraph
  def initialize(work_dir, theta_filename, poster_author=nil)
    @save_dir = work_dir #thetaファイルのあるフォルダ
    @color_list = [
      ["#FF7F7F", "#FF9999", "#FFB2B2", "#FFCCCC", "#FFE5E5"],
      ["#7FBFFF", "#99CCFF", "#B2D8FF", "#CCE5FF", "#E5F2FF"],
      ["#7FFF7F", "#99FF99", "#B2FFB2", "#CCFFCC", "#E5FFE5"],
      ["#BF7FFF", "#CC99FF", "#D8B2FF", "#E5CCFF", "#F2E5FF"],
      ["#FFBF7F", "#FFCC99", "#FFD8B2", "#FFE5CC", "#FFF2E5"],
      ["#FFFF7F", "#FFFF99", "#FFFFB2", "#FFFFCC", "#FFFFE5"],
      ["#FF7FFF", "#FF99FF", "#FFB2FF", "#FFCCFF", "#FFE5FF"],
      ["#BFFF7F", "#CCFF99", "#D8FFB2", "#E5FFCC", "#F2FFE5"]
       ]#kohrin.net/color/color.htmlから引用
    @poster_author = poster_author #ポスター番号と筆者の対応表
    @rank = 2 #上位いくつのトピックまでエッジをひくか
    @theta_vector = Hash.new #θを順番に回収するハッシュを作成
    @nodeID_name = Hash.new #Graphviz上のIDと筆者名
    file_data = open(@save_dir + theta_filename, "r").readlines #ファイルを全部読込む
    poster_name = ""
    poster_num = 0
    
    file_data.each do |line|
      line_split = line.split("\t") #タブ区切り
      
      if poster_name != line_split[0]
        poster_name = line_split[0] #著者名回収
        poster_num +=1
        @nodeID_name[poster_num] = poster_name;
      end
      
      topic_id = line_split[1].to_i + 1 #トピック番号を回収
      probability = line_split[2].to_f #分類確率
      
      if @theta_vector.key?(poster_num) #トピック番号と確率をpush
        @theta_vector[poster_num].push([topic_id, probability])
      else
        vector = Array.new #トピック番号と分類確率を順番に入れる配列を用意
        vector.push([topic_id, probability]) #
        @theta_vector[poster_num] = vector #ファイル名に対応させてベクトル登録
      end
    end
    
    @gv = Gviz.new #グラフデータ作成
    #@gv.global layout: 'neato', overlap: false, splines: true
    @gv.global layout: 'neato', overlap: false
    @gv.edges arrowhead: 'none', color: "#00000030" #透明化
    @gv.nodes style: "filled"
  end
  #トピック分類確率からグラフを作成
  def make_graph(filename)
    total_num = @theta_vector.length #全文章数
    
    @theta_vector.each do |poster_num, vector|
      vector.each do |topic_id, theta| #トピック番号に対応するノードを作成
        @gv.node :"t#{topic_id}", label:"T#{topic_id}", color:@color_list[topic_id-1][0], style:"bold", penwidth:5
      end
      #最初の文章だけ利用
      break
    end
    
    @theta_vector.each_with_index do |(poster_num, vector), i|
      print "\r#{i+1}/#{total_num}"
      make_edges(poster_num, vector) #ポスターごとに近いトピックとエッジを張る
    end
    
    puts "\nGraph mapping ready."
    @gv.save(@save_dir + filename, :png)
    puts "Graph has output."
  end
  
  def make_edges(host_poster, vector)
    vector.each_with_index do |(topic_id, theta), i|
      label = sprintf("%.2f", theta) #エッジに付ける分類確率を取得
      @gv.route :"p#{host_poster}" => :"t#{topic_id}" #エッジを実体化
      
      if (i < @rank) #最低描画数までは線を引く
        @gv.edge :"p#{host_poster}_t#{topic_id}", label:label, len:(1.0-theta)
      else #描画しないがエッジは張る
        @gv.edge :"p#{host_poster}_t#{topic_id}", len:(1.0-theta), style:"invis"
      end
    end
    #最後にノードを実体化
    color_number = ((1-vector[0][1])*5).to_i #色は5段階。20%ごとに薄くなる。
    color_name = @color_list[vector[0][0]- 1][color_number] #トピックに対応した色
    
    if @poster_author
      @gv.node :"p#{host_poster}", label: "#{@nodeID_name[host_poster]}:#{@poster_author[host_poster]}", color:color_name
    else
      @gv.node :"p#{host_poster}", label: "#{@nodeID_name[host_poster]}", color:color_name
    end
  end
  #元のポスターデータから、ポスター番号と筆者名の対応表を作成する
  def set_poster_author(poster_entry)
    @poster_author = Hash.new
    
    poster_entry.each do |entry| #1番目に番号、3番目に著者
      @poster_author[entry[0].to_i] = entry[2]
    end
  end
end

#以下エントリーポイント
if __FILE__==$0
  topic_graph = TopicGraph.new("search001/T4/", "search001.tsv_theta")
  topic_graph.make_graph("search001")
end
