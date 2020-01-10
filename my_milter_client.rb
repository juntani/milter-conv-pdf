# encoding: utf-8

require 'milter/client'
require 'mail'

class MyMilter < Milter::ClientSession
  def initialize(context)
    super(context)
    reset
  end

  def reset
    @headers = []
    @body = ""
  end

  def header(name, value)
    @headers << [name, value]
#    case name
#    when /\ASubject\z/i
#      if @regexp =~ value
#        #reject
#      end
#    end
  end

  def end_of_header
  end

  def body(chunk)
    # store all chunks.
    @body << chunk
  end

  def end_of_message
    add_header("X-My-milter", "on")
    header = ""
    @headers.each do |elem|
      header << elem.join(": ") + "\r\n"
    end
    message = header + "\r\n" + @body
    mail = Mail.new message

    tmp = "/tmp/my_milter"

    new_mail = nil
    pdf_names = []
    if mail.attachments.size > 0
      mail.attachments.each do |elem|
        next unless /\.(docx?|xlsx?)$/ =~ elem.filename
        new_mail ||= Mail.new do
          content_type "multipart/mixed"
          subject "[PDF化] " + mail.subject.to_s
        end

        open(File.join(tmp, elem.filename), "w") do |a|
          a.puts elem.decoded
        end
        system("docker run --rm=true -v #{tmp}:/data libre /data/#{elem.filename}")
        pdf_names << elem.filename.sub(/\.(docx?|xlsx?)$/, ".pdf")
      end
    end

    if new_mail
      body_part = Mail::Part.new(content_type: "multipart/alternative")
      body_part.add_part(Mail::Part.new(
        body: "** PLEASE CARE THIS MAIL **",
        content_type: 'text/plain; charset=UTF-8'
      ))

      body_part.add_part(Mail::Part.new(
        content_type: 'text/html; charset=UTF-8',
        body: <<EOS
        <h1>★このメールには注意してください。★</h1>
        Microsoft Office形式の文書ファイルが添付されていたため、メールシステムでPDF形式に変換しました。
        文書の内容を、まず安全なPDFファイルで確認してください。
        <strong>「マクロを有効に」「コンテンツを有効にする」などの指示があったら、それは詐欺メールです。</strong>
        <hr>
        元のメールを確認したい場合は、添付ファイル「*.eml」を確認してください。
EOS
      ))
      new_mail.add_part(body_part)

      pdf_names.each do |pdf|
        new_mail.add_file(filename: pdf, content: File.read(File.join(tmp, pdf)))
        warn "Added #{pdf}"
      end

      new_mail.add_file(filename: "original.eml", content: message)
      warn "added original.eml"

      open("new_debug.eml", "w") do |dbg|
        dbg.print new_mail.to_s
      end
      open("new_body.txt", "w") do |dbg|
        dbg.print new_mail.body.encoded
      end

      # Assume that there is only one header (hence index is 1)
      change_header('Content-Type', 1, new_mail.header['Content-Type'].to_s)
      change_header('Content-Transfer-Encoding', 1, new_mail.header['Content-Transfer-Encoding'].to_s)
      change_header('Subject', 1, new_mail['subject'].encoded.sub(/^Subject: /, ''))

      replace_body(new_mail.body.encoded)
    end
  end
end

command_line = Milter::Client::CommandLine.new
command_line.run do |client, _options|
  client.register(MyMilter)
end

