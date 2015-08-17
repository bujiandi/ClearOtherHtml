//
//  main.swift
//  ClearOtherHtml
//
//  Created by 慧趣小歪 on 15/8/3.
//  Copyright (c) 2015年 慧趣小歪. All rights reserved.
//

import Foundation

let splitString = "-=~=-=~=-"
let emptyString = ""
println("Hello, World!\(emptyString.componentsSeparatedByString(splitString).count)")

func cleanUnknowHtml(HTML:String, regular:NSRegularExpression) -> String {
    var result:String = ""
    let html:NSString = HTML
    let matchs = regular.matchesInString(HTML, options: NSMatchingOptions(0), range: NSMakeRange(0, html.length))
    var lastRange = NSMakeRange(0, 0)
    
    for match in matchs as! [NSTextCheckingResult] {
        let location = lastRange.location + lastRange.length
        let length = match.range.location - location;
        
        let tmp = html.substringWithRange(NSMakeRange(location, length))
        result += tmp
        lastRange = match.range;
        
        
        let tag = html.substringWithRange(match.rangeAtIndex(2)).lowercaseString
        switch tag {
        case "b","i","u","a","br","h1","h2","h3","h4","h5","h6","h7","li","sub","sup","img":
            result += html.substringWithRange(match.range)
        case "p":
            //break
            if match.rangeAtIndex(1).location == NSNotFound {               //如果是TAG起始
                if match.rangeAtIndex(4).location != NSNotFound {           //如果TAB 以/>结束
                    //result += "<p />" 
                    break
                } else {
                    //result += "<p>"
                    break
                }
            }else {
                //result += "</p>"
                result += "<br>"
            }
        default : break
            //println("抛弃无法识别标记:\(tag)")
        }
    }
    let loaction = lastRange.location + lastRange.length
    if loaction < html.length {
        let length = html.length - loaction
        result += html.substringWithRange(NSMakeRange(loaction, length))
    }
    //println(trimHtml(result))
    return trimHtml(result)
}

func trimHtml(html:String) -> String {
    let html = trim(html)
    // 去除前缀 换行与空格
    if html.hasPrefix("<br>") {
        return trimHtml(html.substringFromIndex(4))
    }
    if html.hasPrefix("<br/>") {
        return trimHtml(html.substringFromIndex(5))
    }
    if html.hasPrefix("</br>") {
        return trimHtml(html.substringFromIndex(5))
    }
    if html.hasPrefix("&nbsp;") {
        return trimHtml(html.substringFromIndex(6))
    }
    // 去除后缀 换行与空格
    if html.hasSuffix("<br>") {
        return trimHtml(html.substringToIndex(html.length - 4))
    }
    if html.hasSuffix("<br/>") {
        return trimHtml(html.substringToIndex(html.length - 5))
    }
    if html.hasSuffix("</br>") {
        return trimHtml(html.substringToIndex(html.length - 5))
    }
    if html.hasSuffix("&nbsp;") {
        return trimHtml(html.substringToIndex(html.length - 6))
    }
    return html
}

let path = "/Users/bujiandi/Documents/TyData.db"

let sqlite = SQLite(path: path, version: 4) {
    (db, oldVersion, newVersion) -> Bool in
    
    return true
}

let (db, error) = sqlite.open()

typealias Chapter = (id:Int64, name:String, pid:Int64, order:Int64, hide:Int64, child:Int64)

var chapters:[Chapter] = []
if let rs = db.select(nil, from: "TYKW_CHAPTER", Where: nil) {
    while rs.next {
        let id = rs.getInt64("CHAPTER_ID")
        let pid = rs.getInt64("CHAPTER_PID")
        let order = rs.getInt64("CHAPTER_NO")
        let hide = rs.getInt64("CHAPTER_TAKE")
        let child = rs.getInt64("CHILD_VALUE")
        let name = rs.getString("CHAPTER_NAME")
        chapters.append((id:id, name:trim(name), pid:pid, order:order, hide:hide, child:child))
        //println("id:\(id) name:\(trim(name))")
        
    }
}

db.insertOrReplace(into: "TYKW_CHAPTER", ["CHAPTER_ID","CHAPTER_NAME","CHAPTER_PID","CHAPTER_NO","CHAPTER_TAKE","CHILD_VALUE"]) {
    (index) -> [String : Any]? in
    if index < chapters.count {
        let chapter = chapters[index]
        return [
            "CHAPTER_ID":chapter.id,
            "CHAPTER_NAME":chapter.name,
            "CHAPTER_PID":chapter.pid,
            "CHAPTER_NO":chapter.order,
            "CHAPTER_TAKE":chapter.hide,
            "CHILD_VALUE":chapter.child
        ]
    } else {
        return nil
    }
}
/*
// 检查替换后的内容
if let rs = db.select(["CHAPTER_ID","CHAPTER_NAME"], from: "TYKW_CHAPTER", Where: nil) {
    while rs.next {
        let id = rs.getInt64("CHAPTER_ID")
        let name = rs.getString("CHAPTER_NAME")
        //chapters.append((id:id, name:trim(name)))
        println("id:\(id) name:\(name)")
        
    }
}
*/

typealias Question = (
    id:Int64,
    content:String,
    answer:[String],
    analytical:String,
    
    pid:Int64,
    top:Int64,
    cid:Int64,
    qid:Int64,
    type:Int64,
    order:Int64,
    version:Int64,
    correct:Int64
)

let regular = NSRegularExpression(pattern: "<\\s*(/)?\\s*([:_A-Za-z0-9]+)([^>]*?)(/)?\\s*>", options: NSRegularExpressionOptions.CaseInsensitive, error: nil)!

func cleanAnswersHtml(answers:[String]) -> [String] {
    var result:[String] = []
    var hasRepeatKey:Bool = true
    for answer in answers {
        let answer = cleanUnknowHtml(answer, regular)
        let key = answer.unicodeScalars[0]
        hasRepeatKey = hasRepeatKey && (answer.length > 1 ? key.value == answer.unicodeScalars[1].value : false)
        result.append(trimHtml(answer.substringFromIndex(1)))
    }
    if hasRepeatKey {
        return cleanAnswersHtml(result)
    }
    
    for var i:Int = 0; i<result.count; i++ {
        result[i] = "\(UnicodeScalar(i + 65))\(result[i])"
    }
    return result
}

var questions:[Question] = []
if let rs = db.select(nil, from: "TYKW_EXERCISES", Where: nil) {
    while rs.next {
        let id = rs.getInt64("EXERCISES_ID")
        let content = rs.getString("CONTENT")
        let analytical = rs.getString("ANALYTICAL")
        let answerString = rs.getString("ANSWER")
        
        var answers:[String] = []
        if !answerString.isEmpty {
            
            answers = cleanAnswersHtml(answerString.componentsSeparatedByString(splitString))
            //println(answers)
        }
        
        let question:Question = (
            id:id,
            content:cleanUnknowHtml(content, regular),
            answer:answers,
            analytical:cleanUnknowHtml(analytical, regular),
            
            pid:rs.getInt64("EXERCISES_PID"),
            top:rs.getInt64("TOP_ID"),
            cid:rs.getInt64("CHAPTER_ID"),
            qid:rs.getInt64("QUESTION_ID"),
            type:rs.getInt64("QUESTION_TYPE"),
            order:rs.getInt64("QUESTION_CODE"),
            version:rs.getInt64("VERSION"),
            correct:rs.getInt64("CORRECT_ANSWER")
        )
        questions.append(question)
        //println("id:\(id) name:\(question.content)")
        
    }
}

db.insertOrReplace(into: "TYKW_EXERCISES", ["EXERCISES_ID","CONTENT","ANALYTICAL","ANSWER","EXERCISES_PID","TOP_ID","CHAPTER_ID","QUESTION_ID", "QUESTION_TYPE", "QUESTION_CODE","VERSION","CORRECT_ANSWER"]) {
    (index) -> [String : Any]? in
    if index < questions.count {
        let question = questions[index]
        let answer = question.answer.count > 0 ? question.answer.componentsJoinedByString(splitString) : ""
        return [
            "EXERCISES_ID":question.id,
            "CONTENT":question.content,
            "ANALYTICAL":question.analytical,
            "ANSWER":answer,
            
            "EXERCISES_PID":question.pid,
            "TOP_ID":question.top,
            "CHAPTER_ID":question.cid,
            "QUESTION_ID":question.qid,
            "QUESTION_TYPE":question.type,
            "QUESTION_CODE":question.order,
            "VERSION":question.version,
            "CORRECT_ANSWER":question.correct
        ]
    } else {
        return nil
    }
}
