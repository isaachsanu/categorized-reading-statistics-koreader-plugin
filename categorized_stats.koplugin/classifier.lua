local Classifier = {}

function Classifier.resolve(md5, collection_index)
    local collection_entry = md5 and collection_index.by_md5[md5]
    if not collection_entry then
        return {
            collections = {},
            files = {},
            reason = "No matching collection item",
        }
    end

    return {
        collections = collection_entry.collections,
        files = collection_entry.files,
        reason = "Matched collection",
    }
end

return Classifier
