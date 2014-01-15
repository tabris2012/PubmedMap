#!/usr/bin/ruby
# coding: utf-8
# 検索ワードから関連研究者を探す
#ここからサブルーチン
def dump_list(filename, list)
  file = open(filename, "w")
  list.each do |key, value|
    file.write(key + "\t" + value.to_s + "\n")
  end
end

#ここからエントリー
require '../WebAbstract/WebAbstract'
require '../WebAbstract/KeywordScore'
require 'fileutils'

get_web_flag = false #デバッグ用ウェブ検索フラグ
#検索ワード設定
search_words = "diabetes insulin clearance"
web_abst = WebAbstract.new() #検索オブジェクト展開
#論文検索し、筆者リストを得る
#author_list = web_abst.webAuthorsByWords(search_words)
# {Author name, 出現回数},...

got_xml = open("./data/testSearch.xml", "r").read
author_list = web_abst.parseXMLtoAuthors(got_xml)
author_list = author_list.sort{|a,b| b[1] <=> a[1]} #出現数順に並び替え

dump_list("./data/author_list.txt", author_list)

if get_web_flag
  author_list.each do |key, value|
    if value < 2
      break #出現頻度が低ければ終了
    end
  
    web_abst.reInit
    web_abst.webAbstractByAuthor(key)
    web_abst.dumpAbstract(key.gsub(/(\s|　)+/, '')) #スペースを除いてファイル出力
  end
end

key_score = KeywordScore.new
puts "Make word lists from abstracts of each authors..."
output_folder = "WordScore"

if !File.exist?(output_folder)
  Dir.mkdir(output_folder)
end

author_list.each_with_index do |(key, value), i|
  if value < 2
    break #出現頻度が低ければ終了
  end
  
  print "\r#{i}"
  filename = key.gsub(/(\s|　)+/, '')+".txt"
  file = open("./Abstract/"+filename).read
  
  word_list = key_score.getFreq(file)
  #スコアの大きい順に並び替え
  word_list = word_list.sort{|a,b| b[1] <=> a[1]}
  key_score.dump_doc_word(word_list, output_folder+"/"+filename)
end

puts "\nDone."
