function append_tag(tag, timestamp, record)
    split=mysplit(record["Path"], "/")
    new_record = record
    new_record["host"] = split[#split -1]
    new_record["runid"] = split[#split -2]
    new_record["test"] = split[#split -3]
    return 1, timestamp, new_record
end

function mysplit (inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={}
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                table.insert(t, str)
        end
        return t
end
