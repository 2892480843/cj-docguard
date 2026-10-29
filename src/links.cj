package docguard

import std.collection.*

// Markdown link scanner, deliberately separate from filesystem/qualification.
// Offsets stay UTF-8 byte offsets so source lines and original targets survive.
private func mdSpace(b: Byte): Bool { b == 32 || b == 9 || b == 10 || b == 13 }
private func mdPunctuation(b: Byte): Bool { (b >= 33 && b <= 47) || (b >= 58 && b <= 64) || (b >= 91 && b <= 96) || (b >= 123 && b <= 126) }
private func mdLower(s: String): String {
    let bytes = s.toArray()
    for (i in 0..bytes.size) { if (bytes[i] >= 65 && bytes[i] <= 90) { bytes[i] += 32 } }
    return String.fromUtf8(bytes)
}
private func mdBlank(bytes: Array<Byte>, a: Int64, b: Int64): Unit {
    for (i in a..b) { if (bytes[i] != 10 && bytes[i] != 13) { bytes[i] = 32 } }
}
private func mdRun(bytes: Array<Byte>, p: Int64, b: Byte): Int64 {
    var end = p
    while (end < bytes.size && bytes[end] == b) { end++ }
    return end
}
private func mdCodeEnd(bytes: Array<Byte>, p: Int64): Int64 {
    let after = mdRun(bytes,p,96); let n = after-p
    var q = after
    while (q < bytes.size) {
        if (bytes[q] == 96) { let end = mdRun(bytes,q,96); if (end-q == n) { return end }; q=end }
        else { q++ }
    }
    return after
}
private func mdLineEnd(bytes: Array<Byte>, p: Int64): Int64 { var end=p; while(end<bytes.size && bytes[end]!=10){end++}; return end }
private func mdSkipSpace(bytes: Array<Byte>, p: Int64): Int64 { var end=p; while(end<bytes.size && mdSpace(bytes[end])){end++};return end }
private func mdLabel(s: String): String {
    var out=""; var gap=false
    for (r in mdLower(s).toRuneArray()) {
        if (r==r' ' || r==r'\t' || r==r'\n' || r==r'\r') { gap = !out.isEmpty() }
        else { if(gap){out+=" "};out+=r.toString();gap=false }
    }
    return out
}
private func mdBracketEnd(bytes: Array<Byte>, p: Int64): Int64 {
    var q=p+1; var depth: Int64=1
    while(q<bytes.size && q-p<=4096){
        if(bytes[q]==92 && q+1<bytes.size && mdPunctuation(bytes[q+1])){q+=2;continue}
        if(bytes[q]==96){q=mdCodeEnd(bytes,q);continue}
        if(bytes[q]==91){depth++;if(depth>32){return -1}}
        if(bytes[q]==93){depth--;if(depth==0){return q}}
        q++
    }
    return -1
}
// Hide non-rendered content while retaining UTF-8 byte and line coordinates.
private func mdVisible(content: String, isMarkdown!: Bool = true): String {
    let out=content.toArray();var p: Int64=0;var fence: Byte=0;var fenceSize: Int64=0
    var commentUntil: Int64=0;var inlineUntil: Int64=0;var listIndent: Int64=0
    while(p<out.size){
        let end=mdLineEnd(out,p)
        var start=p;while(start<end && out[start]==32){start++}
        // Container prefixes do not count as code indentation.
        while(start<end && out[start]==62){start++;if(start<end && out[start]==32){start++}}
        var n=if(start<end && (out[start]==96 || out[start]==126)){mdRun(out,start,out[start])-start}else{0}
        if(isMarkdown && fence!=0){
            let closes=start<end && out[start]==fence && n>=fenceSize && String.fromUtf8(out[start+n..end]).trimAscii().isEmpty()
            mdBlank(out,p,end);if(closes){fence=0};p=end+1;continue
        }
        var q=p
        while(q<end){
            if(q<commentUntil){let stop=if(commentUntil<end){commentUntil}else{end};mdBlank(out,q,stop);q=stop;continue}
            if(isMarkdown && q<inlineUntil){q=if(inlineUntil<end){inlineUntil}else{end};continue}
            if(isMarkdown && out[q]==92 && q+1<end && mdPunctuation(out[q+1])){q+=2;continue}
            // Compare syntax bytes directly: a fixed String slice could split adjacent Unicode.
            if(q+4<=out.size && out[q]==60 && out[q+1]==33 && out[q+2]==45 && out[q+3]==45){
                let close=findByteString(content,"-->",q+4);commentUntil=if(close<0){out.size}else{close+3};continue
            }
            if(isMarkdown && out[q]==96){inlineUntil=mdCodeEnd(out,q);q=if(inlineUntil<end){inlineUntil}else{end};continue}
            q++
        }
        if(!isMarkdown){p=end+1;continue}
        start=p;while(start<end && out[start]==32){start++}
        var indent=start-p
        while(start<end && out[start]==62){start++;if(start<end && out[start]==32){start++};indent=0}
        var markerEnd=start
        if(start+1<end && (out[start]==45 || out[start]==43 || out[start]==42) && mdSpace(out[start+1])){markerEnd=start+2}
        else{while(markerEnd<end && digit(out[markerEnd])){markerEnd++};if(markerEnd>start && markerEnd+1<end && (out[markerEnd]==46 || out[markerEnd]==41) && mdSpace(out[markerEnd+1])){markerEnd+=2}else{markerEnd=start}}
        if(markerEnd>start){listIndent=markerEnd-p;start=markerEnd;indent=0}
        else if(listIndent>0 && indent>=listIndent){indent-=listIndent}
        else if(start<end){listIndent=0}
        n=if(start<end && (out[start]==96 || out[start]==126)){mdRun(out,start,out[start])-start}else{0}
        if(indent<4 && n>=3){fence=out[start];fenceSize=n;inlineUntil=0;mdBlank(out,p,end)}
        else if(indent>=4 || (start<end && out[start]==9)){mdBlank(out,p,end)}
        p=end+1
    }
    // Raw HTML bodies are not Markdown; retain opening tags for their actual IDs.
    let rawSearch=out.clone();p=0
    if(isMarkdown){while(p<rawSearch.size){
        if(rawSearch[p]==92 && p+1<rawSearch.size && mdPunctuation(rawSearch[p+1])){mdBlank(rawSearch,p,p+2);p+=2;continue}
        if(rawSearch[p]==96){let end=mdCodeEnd(rawSearch,p);if(end>mdRun(rawSearch,p,96)){mdBlank(rawSearch,p,end)};p=end}else{p++}
    }}
    let lower=mdLower(String.fromUtf8(rawSearch))
    for(tag in ["script","style","pre"]){
        p=0
        while(p<out.size){
            let open=findByteString(lower,"<"+tag,p);if(open<0){break};let after=open+tag.size+1
            if(after>=out.size || !(mdSpace(out[after]) || out[after]==62)){p=after;continue}
            var begin=after;var delimiter: Byte=0
            while(begin<out.size){
                if(delimiter!=0){if(out[begin]==delimiter){delimiter=0}}
                else if(out[begin]==34 || out[begin]==39){delimiter=out[begin]}
                else if(out[begin]==62){break}
                else if(out[begin]==60){break};begin++
            }
            if(begin>=out.size){break};if(out[begin]!=62){p=begin+1;continue}
            let close=findByteString(lower,"</"+tag,begin+1)
            mdBlank(out,begin+1,if(close<0){out.size}else{close});p=if(close<0){out.size}else{close+tag.size+2}
        }
    }
    return String.fromUtf8(out)
}
private func mdLetter(b: Byte): Bool { (b>=65 && b<=90)||(b>=97 && b<=122) }
private func mdAutolink(target: String): Bool {
    let b=target.toArray()
    for(c in b){if(c<=32 || c==127 || c==34 || c==39 || c==61 || c==60 || c==62){return false}}
    let colon=findByteString(target,":",0)
    if(colon>=2 && colon<=32 && mdLetter(b[0])){
        for(i in 1..colon){if(!(mdLetter(b[i]) || digit(b[i]) || b[i]==43 || b[i]==45 || b[i]==46)){return false}};return true
    }
    if(colon>=0){return false}
    let at=findByteString(target,"@",0)
    return at>0 && at<target.size-1 && findByteString(target,"@",at+1)<0 && target[at+1..].contains(".")
}
private func mdHex(b: Byte): Int64 {
    if(b>=48 && b<=57){return Int64(b-48)}
    if(b>=65 && b<=70){return Int64(b-65)+10}
    if(b>=97 && b<=102){return Int64(b-97)+10}
    return -1
}
func decodeLinkPercent(s: String): String {
    let bytes=s.toArray();let out=ArrayList<Byte>();var p: Int64=0
    while(p<bytes.size){
        if(bytes[p]==37){
            if(p+2>=bytes.size || mdHex(bytes[p+1])<0 || mdHex(bytes[p+2])<0){throw Exception("Malformed percent encoding")}
            let b=UInt8(mdHex(bytes[p+1])*16+mdHex(bytes[p+2]));if(b==0 || b<32 || b==127){throw Exception("Control character in link target")};out.add(b);p+=3
        }else{if(bytes[p]<32 || bytes[p]==127){throw Exception("Control character in link target")};out.add(bytes[p]);p++}
    }
    return String.fromUtf8(out.toArray())
}
// Decode Markdown punctuation escapes and the common/numeric HTML entities.
// Unknown named entities are explicit unknowns, never falsely passing literals.
func decodeLinkText(s: String): String {
    let bytes=s.toArray();let out=ArrayList<Byte>();var p: Int64=0
    while(p<bytes.size){
        if(bytes[p]==92 && p+1<bytes.size && mdPunctuation(bytes[p+1])){out.add(bytes[p+1]);p+=2;continue}
        if(bytes[p]==38){
            let end=findByteString(s,";",p+1)
            if(end>p && end-p<=34){
                let entity=s[p+1..end];var value=""
                if(entity=="amp"){value="&"}else if(entity=="quot"){value="\""}else if(entity=="apos"){value="'"}else if(entity=="lt"){value="<"}else if(entity=="gt"){value=">"}else if(entity=="nbsp"){value=" "}
                else if(entity.startsWith("#")){
                    let digits=entity.toArray();let hex=digits.size>2 && (digits[1]==120 || digits[1]==88);var q: Int64=if(hex){2}else{1};var cp: Int64=0
                    if(q==digits.size){throw Exception("Invalid numeric HTML entity")}
                    while(q<digits.size){let d=if(hex){mdHex(digits[q])}else if(digit(digits[q])){Int64(digits[q]-48)}else{-1};if(d<0){throw Exception("Invalid numeric HTML entity")};cp=cp*(if(hex){16}else{10})+d;if(cp>0x10ffff){throw Exception("Invalid numeric HTML entity")};q++}
                    if(cp==0 || (cp>=0xd800 && cp<=0xdfff)){throw Exception("Invalid numeric HTML entity")};value=Rune(UInt32(cp)).toString()
                }else{
                    var named=entity.size>0
                    for(b in entity.toArray()){if(!((b>=65 && b<=90)||(b>=97 && b<=122)||digit(b))){named=false}}
                    if(named){throw Exception("Unsupported named HTML entity: " + entity)}
                }
                if(!value.isEmpty()){for(b in value.toArray()){out.add(b)};p=end+1;continue}
            }
        }
        out.add(bytes[p]);p++
    }
    return String.fromUtf8(out.toArray())
}
private class MdDestination {
    let target: String;let end: Int64
    init(target: String,end: Int64){this.target=target;this.end=end}
}
private func mdDestination(s: String,p: Int64): MdDestination {
    let b=s.toArray();if(p>=b.size){return MdDestination("",p)}
    if(b[p]==60){
        var q=p+1
        while(q<b.size && b[q]!=10 && b[q]!=13){
            if(b[q]==92 && q+1<b.size && mdPunctuation(b[q+1])){q+=2;continue}
            if(b[q]==62){return MdDestination(s[p+1..q],q+1)}
            if(b[q]==60){return MdDestination("",-1)};q++
        }
        return MdDestination("",-1)
    }
    var q=p;var depth: Int64=0
    while(q<b.size && q-p<=8192){
        if(b[q]==92 && q+1<b.size && mdPunctuation(b[q+1])){q+=2;continue}
        if(b[q]==40){depth++;if(depth>32){return MdDestination("",-1)}}
        else if(b[q]==41){if(depth==0){break};depth--}
        else if(mdSpace(b[q]) || b[q]<32){break}
        q++
    }
    return if(depth==0){MdDestination(s[p..q],q)}else{MdDestination("",-1)}
}
private func mdTitleEnd(s: String,p: Int64): Int64 {
    let b=s.toArray();if(p>=b.size || (b[p]!=34 && b[p]!=39 && b[p]!=40)){return -1}
    let close: Byte=if(b[p]==40){41}else{b[p]};var q=p+1
    while(q<b.size && q-p<=8192){
        if(b[q]==92 && q+1<b.size && mdPunctuation(b[q+1])){q+=2;continue}
        if(b[q]==close){return q+1};if(b[q]==10 && q+1<b.size && b[q+1]==10){return -1};q++
    };return -1
}
private func mdInlineDestination(s: String,p: Int64): MdDestination {
    let b=s.toArray();let start=mdSkipSpace(b,p+1)
    let destination=mdDestination(s,start);if(destination.end<0){return destination}
    var q=mdSkipSpace(b,destination.end)
    if(q<b.size && b[q]==41){return MdDestination(destination.target,q+1)}
    if(q==destination.end){return MdDestination("",-1)}
    let end=mdTitleEnd(s,q);if(end<0){return MdDestination("",-1)}
    q=mdSkipSpace(b,end)
    return if(q<b.size && b[q]==41){MdDestination(destination.target,q+1)}else{MdDestination("",-1)}
}
private func mdMaskInline(bytes: Array<Byte>, multilineOnly!: Bool = false): Unit {
    var code: Int64=0
    while(code<bytes.size){
        if(bytes[code]==92 && code+1<bytes.size && mdPunctuation(bytes[code+1])){code+=2;continue}
        if(bytes[code]==96){
            let end=mdCodeEnd(bytes,code)
            if(end>mdRun(bytes,code,96)){
                var multiline=false;for(i in code..end){if(bytes[i]==10){multiline=true}}
                if(!multilineOnly || multiline){mdBlank(bytes,code,end)}
            };code=end
        }else{code++}
    }
}
private class MdReferences {
    let definitions: HashMap<String,String>;let scan: Array<Byte>
    init(definitions: HashMap<String,String>,scan: Array<Byte>){this.definitions=definitions;this.scan=scan}
}
// Shared definition collection prevents heading and link interpretation diverging.
private func mdReferences(original: String): MdReferences {
    let definitionBytes=original.toArray();mdMaskInline(definitionBytes)
    let visible=String.fromUtf8(definitionBytes);let b=visible.toArray();let scan=original.toArray();let definitions=HashMap<String,String>()
    var p: Int64=0
    while(p<b.size){
        let end=mdLineEnd(b,p);var start=p
        while(start<end && (b[start]==32 || b[start]==9)){start++}
        if(start<end && b[start]==91){
            let close=mdBracketEnd(b,start)
            if(close>start && close-start<=1000 && close+1<end && b[close+1]==58){
                let label=mdLabel(visible[start+1..close]);let destStart=mdSkipSpace(b,close+2);let d=mdDestination(visible,destStart)
                if(!label.isEmpty() && d.end>=destStart && (d.end>destStart || (destStart<b.size && b[destStart]==60))){
                    let tail=mdSkipSpace(b,d.end);var consumed=mdLineEnd(b,d.end);var valid=tail>=b.size || tail>consumed
                    if(tail<b.size && tail<=consumed && (b[tail]==34 || b[tail]==39 || b[tail]==40)){
                        let titleEnd=mdTitleEnd(visible,tail)
                        if(titleEnd>0 && visible[titleEnd..mdLineEnd(b,titleEnd)].trimAscii().isEmpty()){valid=true;consumed=mdLineEnd(b,titleEnd)}
                    }
                    if(valid){if(!definitions.contains(label)){definitions[label]=d.target};mdBlank(scan,p,consumed);p=consumed+1;continue}
                }
            }
        }
        p=end+1
    }
    return MdReferences(definitions,scan)
}
func markdownLinks(content: String): J { mdScanLinks(mdReferences(mdVisible(content))) }
private func mdScanLinks(references: MdReferences): J {
    let scan=references.scan;let definitions=references.definitions
    let s=String.fromUtf8(scan);let rows=J.arr();var p: Int64=0;var line: Int64=1
    while(p<scan.size){
        if(scan[p]==10){line++;p++;continue}
        if(scan[p]==92 && p+1<scan.size && mdPunctuation(scan[p+1])){p+=2;continue}
        if(scan[p]==96){let after=mdCodeEnd(scan,p);for(i in p..after){if(scan[i]==10){line++}};p=after;continue}
        if(scan[p]==91){
            let close=mdBracketEnd(scan,p)
            if(close>p){
                var end=close+1;var target="";var syntax="";let image=p>0 && scan[p-1]==33
                if(end<scan.size && scan[end]==40){let d=mdInlineDestination(s,end);if(d.end>0){target=d.target;end=d.end;syntax="inline"}}
                if(syntax.isEmpty()){
                    let own=mdLabel(s[p+1..close]);var label=own;var explicit=false
                    if(end<scan.size && scan[end]==91){let c=mdBracketEnd(scan,end);if(c>=end){label=mdLabel(s[end+1..c]);if(label.isEmpty()){label=own};end=c+1;explicit=true}}
                    if(definitions.contains(label)){target=definitions[label];syntax="reference"}
                    else if(explicit){p=close+1;continue}
                }
                if(!syntax.isEmpty()){
                    rows.add(J.obj().put("target",J.str(target)).put("line",J.num(line)).put("syntax",J.str(if(image){"image-"+syntax}else{syntax})).put("destination_start",J.num(close+1)).put("destination_end",J.num(end)))
                    for(i in p..end){if(scan[i]==10){line++}};p=end;continue
                }
            }
        }
        if(scan[p]==60){
            let end=findByteString(s,">",p+1)
            if(end>p && end-p<=8192){
                let target=s[p+1..end]
                if(mdAutolink(target)){
                    rows.add(J.obj().put("target",J.str(if(target.contains(":")){target}else{"mailto:"+target})).put("line",J.num(line)).put("syntax",J.str("autolink")));p=end+1;continue
                }
            }
        }
        p++
    }
    return rows
}
// Actual HTML references retain their encoded source spelling. Qualification
// decodes entities later; every duplicate attribute is checked conservatively.
func htmlLinks(content: String): J {
    let b=content.toArray();let lower=mdLower(content);let rows=J.arr()
    var p: Int64=0;var line: Int64=1
    while(p<b.size){
        if(b[p]==10){line++;p++;continue}
        if(b[p]!=60){p++;continue}
        if(p+4<=b.size && b[p+1]==33 && b[p+2]==45 && b[p+3]==45){
            let close=findByteString(content,"-->",p+4);let end=if(close<0){b.size}else{close+3}
            for(i in p..end){if(b[i]==10){line++}};p=end;continue
        }
        if(p+1>=b.size || !mdLetter(b[p+1])){p++;continue}
        var q=p+1
        while(q<b.size && (mdLetter(b[q]) || digit(b[q]) || b[q]==45)){q++}
        let tag=lower[p+1..q]
        if(q>=b.size || !(mdSpace(b[q]) || b[q]==62 || b[q]==47)){p=q;continue}
        let pending=J.arr();var closed=false;var valid=true
        while(q<b.size){
            q=mdSkipSpace(b,q);if(q>=b.size){break}
            if(b[q]==62){q++;closed=true;break}
            if(b[q]==47 && q+1<b.size && b[q+1]==62){q+=2;closed=true;break}
            let start=q
            while(q<b.size && !mdSpace(b[q]) && b[q]!=61 && b[q]!=62 && b[q]!=47 && b[q]!=60 && b[q]!=34 && b[q]!=39){q++}
            if(q==start){valid=false;break}
            let name=lower[start..q];q=mdSkipSpace(b,q)
            if(q>=b.size || b[q]!=61){continue}
            q=mdSkipSpace(b,q+1);var value=""
            if(q<b.size && (b[q]==34 || b[q]==39)){
                let delimiter=b[q];q++;let a=q;while(q<b.size && b[q]!=delimiter){q++}
                if(q>=b.size){valid=false;break};value=content[a..q];q++
            }else{
                let a=q;while(q<b.size && !mdSpace(b[q]) && b[q]!=62){q++};value=content[a..q]
                if(q==a){valid=false;break}
            }
            let href=name=="href" && (tag=="a" || tag=="area" || tag=="link" || tag=="base")
            let src=name=="src" && (tag=="script" || tag=="img" || tag=="source" || tag=="iframe" || tag=="audio" || tag=="video" || tag=="track" || tag=="input" || tag=="embed")
            let unsupported=(name=="srcset" && (tag=="img" || tag=="source")) || (name=="imagesrcset" && tag=="link")
            if(href || src || unsupported || (name=="poster" && tag=="video") || (name=="data" && tag=="object")){
                var attrLine=line;for(i in p..start){if(b[i]==10){attrLine++}}
                pending.add(J.obj().put("target",J.str(value)).put("line",J.num(attrLine)).put("syntax",J.str("html-"+name)).put("tag",J.str(tag)).put("unsupported",J.boolean(unsupported)))
            }
        }
        if(valid && closed){
            for(row in pending.items){
                var count: Int64=0;for(other in pending.items){if(other.get("syntax").s()==row.get("syntax").s()){count++}}
                row.put("ambiguous",J.boolean(count>1));rows.add(row)
            }
        }
        if(valid && closed && (tag=="script" || tag=="style" || tag=="textarea" || tag=="title")){
            var close=findByteString(lower,"</"+tag,q)
            while(close>=0){let after=close+tag.size+2;if(after>=b.size || mdSpace(b[after]) || b[after]==62 || b[after]==47){break};close=findByteString(lower,"</"+tag,after)}
            q=if(close<0){b.size}else{close}
        }
        if(q<=p){q=p+1};for(i in p..q){if(b[i]==10){line++}};p=q
    }
    return rows
}
private func mdPlainHeading(s: String, definitions: HashMap<String,String>): String {
    let b=s.toArray();var out="";var p: Int64=0
    while(p<b.size){
        if(b[p]==92 && p+1<b.size && mdPunctuation(b[p+1])){out+=s[p+1..p+2];p+=2;continue}
        if(b[p]==60){let end=findByteString(s,">",p+1);if(end>=0){p=end+1;continue}}
        if(b[p]==91 || (b[p]==33 && p+1<b.size && b[p+1]==91)){
            let start=if(b[p]==33){p+1}else{p};let close=mdBracketEnd(b,start)
            if(close>start){out+=mdPlainHeading(s[start+1..close],definitions);p=close+1;if(p<b.size && b[p]==40){let d=mdInlineDestination(s,p);if(d.end>0){p=d.end}}else if(p<b.size && b[p]==91){let refEnd=mdBracketEnd(b,p);if(refEnd>p){let raw=s[p+1..refEnd];let label=mdLabel(if(raw.isEmpty()){s[start+1..close]}else{raw});if(definitions.contains(label)){p=refEnd+1}}};continue}
        }
        if(b[p]==96){let after=mdCodeEnd(b,p);let n=mdRun(b,p,96)-p;if(after>p+n){out+=s[p+n..after-n];p=after;continue}}
        if(b[p]==95 && p>0 && p+1<b.size && (mdLetter(b[p-1]) || digit(b[p-1]) || b[p-1]>=128) && (mdLetter(b[p+1]) || digit(b[p+1]) || b[p+1]>=128)){out+="_";p++;continue}
        if(b[p]==42 || b[p]==95 || b[p]==126){p++;continue}
        var end=p+1;while(end<b.size && b[end]>=128 && b[end]<192){end++};out+=s[p..end];p=end
    }
    return decodeLinkText(out)
}
func isMarkdownDocument(file: String): Bool {
    let lower=mdLower(file);return lower.endsWith(".md") || lower.endsWith(".markdown")
}
func headingSlug(s: String): String { mdHeadingSlug(s,HashMap<String,String>()) }
private func mdHeadingSlug(s: String, definitions: HashMap<String,String>): String {
    var out=""
    for(r in mdLower(mdPlainHeading(s,definitions)).trimAscii().toRuneArray()){
        if(r==r' ' || r==r'\t' || r==r'\n'){out+="-"}
        else if((r>=r'a' && r<=r'z') || (r>=r'0' && r<=r'9') || r==r'-' || r==r'_' || UInt32(r)>127){out+=r.toString()}
    }
    return out
}
private func mdAddHeading(anchors: HashSet<String>,title: String,definitions: HashMap<String,String>): Unit {
    try {
        let base=mdHeadingSlug(title,definitions);var candidate=base;var n: Int64=0
        while(anchors.contains(candidate)){n++;candidate=base+"-"+n.toString()};anchors.add(candidate)
    } catch(_: Exception) { /* Unsupported heading entities must not invalidate unrelated anchors. */ }
}
func markdownAnchors(content: String, isMarkdown!: Bool = true): HashSet<String> {
    let anchors=HashSet<String>();let visible=mdVisible(content,isMarkdown: isMarkdown)
    if(isMarkdown){
    let references=mdReferences(visible);let headingBytes=references.scan;mdMaskInline(headingBytes,multilineOnly: true)
    let lines=String.fromUtf8(headingBytes).split("\n");var paragraph="";var container="";var listIndent: Int64=0
    for(line in lines){
        let raw=line.toArray();var start: Int64=0;var quotes: Int64=0
        while(start<raw.size && raw[start]==32){start++}
        while(start<raw.size && raw[start]==62){quotes++;start++;if(start<raw.size && raw[start]==32){start++}}
        let quoteKey=quotes.toString();var markerEnd=start
        if(start+1<raw.size && (raw[start]==45 || raw[start]==43 || raw[start]==42) && mdSpace(raw[start+1])){markerEnd=start+2}
        else{while(markerEnd<raw.size && digit(raw[markerEnd])){markerEnd++};if(markerEnd>start && markerEnd+1<raw.size && (raw[markerEnd]==46 || raw[markerEnd]==41) && mdSpace(raw[markerEnd+1])){markerEnd+=2}else{markerEnd=start}}
        let newItem=markerEnd>start
        if(newItem){listIndent=markerEnd;start=markerEnd;paragraph=""}
        else if(listIndent>0 && start<listIndent){listIndent=0}
        let key=quoteKey+":"+listIndent.toString()
        if(key!=container){paragraph="";container=key}
        let trim=line[start..].trimAscii();let b=trim.toArray();var n: Int64=0
        if(trim.isEmpty()){paragraph="";continue}
        while(n<b.size && b[n]==35){n++}
        if(n>=1 && n<=6 && (n==b.size || mdSpace(b[n]))){
            var title=trim[n..].trimAscii();let t=title.toArray();var last=t.size
            while(last>0 && t[last-1]==35){last--};if(last<t.size && (last==0 || mdSpace(t[last-1]))){title=title[..last].trimAscii()}
            mdAddHeading(anchors,title,references.definitions);paragraph=""
        }else{
            var underline=b.size>0 && (b[0]==61 || b[0]==45)
            for(c in b){if(c!=b[0]){underline=false}}
            if(underline && !paragraph.isEmpty() && !newItem){mdAddHeading(anchors,paragraph,references.definitions);paragraph="";continue}
            var rule=b.size>0 && (b[0]==45 || b[0]==42 || b[0]==95);var count: Int64=0
            for(c in b){if(c==b[0]){count++}else if(c!=32 && c!=9){rule=false}}
            if(underline || (rule && count>=3) || trim.startsWith("<")){paragraph=""}
            else{if(!paragraph.isEmpty()){paragraph+=" "};paragraph+=trim}
        }
    }
    }
    // Link destinations/titles and reference definitions are not rendered HTML.
    // Reuse the actual link parser so literal/unrecognized brackets stay visible.
    let bytes=if(isMarkdown){mdReferences(visible).scan}else{visible.toArray()}
    if(isMarkdown){
        let references=mdReferences(visible)
        for(row in mdScanLinks(references).items){
            let start=number(row,"destination_start",-1);let end=number(row,"destination_end",-1)
            if(start>=0 && end>start){mdBlank(bytes,start,end)}
        }
    }
    // Only quoted/unquoted real attributes, outside code/comments, count as IDs.
    let html=String.fromUtf8(bytes);var p: Int64=0
    while(p<bytes.size){
        if(isMarkdown && bytes[p]==92 && p+1<bytes.size && mdPunctuation(bytes[p+1])){p+=2;continue}
        if(isMarkdown && bytes[p]==96){p=mdCodeEnd(bytes,p);continue}
        if(bytes[p]!=60 || p+1>=bytes.size || !mdLetter(bytes[p+1])){p++;continue}
        var q=p+1
        while(q<bytes.size && (mdLetter(bytes[q]) || digit(bytes[q]) || bytes[q]==45)){q++}
        let tag=mdLower(html[p+1..q])
        if(q>=bytes.size || !(mdSpace(bytes[q]) || bytes[q]==62 || bytes[q]==47)){p=q;continue}
        let pending=ArrayList<String>();var valid=true;var closed=false
        while(q<bytes.size){
            q=mdSkipSpace(bytes,q);if(q>=bytes.size){break}
            if(bytes[q]==62){q++;closed=true;break}
            if(bytes[q]==47 && q+1<bytes.size && bytes[q+1]==62){q+=2;closed=true;break}
            let start=q
            while(q<bytes.size && (mdLetter(bytes[q]) || digit(bytes[q]) || bytes[q]==45 || bytes[q]==95 || bytes[q]==58)){q++}
            if(q==start){valid=false;break}
            let name=mdLower(html[start..q]);q=mdSkipSpace(bytes,q)
            if(q<bytes.size && bytes[q]==61){
                q=mdSkipSpace(bytes,q+1);var value=""
                if(q<bytes.size && (bytes[q]==34 || bytes[q]==39)){
                    let delimiter=bytes[q];q++;let a=q;while(q<bytes.size && bytes[q]!=delimiter && bytes[q]!=60){q++}
                    if(q>=bytes.size || bytes[q]!=delimiter){valid=false;break};value=html[a..q];q++
                }else{
                    let a=q
                    while(q<bytes.size && !mdSpace(bytes[q]) && bytes[q]!=62){if(bytes[q]==34 || bytes[q]==39 || bytes[q]==61 || bytes[q]==60 || bytes[q]==96){valid=false;break};q++}
                    if(!valid || q==a){valid=false;break};value=html[a..q]
                }
                if(q<bytes.size && !mdSpace(bytes[q]) && bytes[q]!=62 && bytes[q]!=47){valid=false;break}
                if(name=="id" || (tag=="a" && name=="name")){try {pending.add(decodeLinkText(value))}catch(_: Exception){}}
            }
        }
        if(valid && closed){for(value in pending){anchors.add(value)}}
        p=if(q>p){q}else{p+1}
    }
    return anchors
}
