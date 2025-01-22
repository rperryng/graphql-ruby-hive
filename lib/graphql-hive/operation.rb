module GraphQLHive
  Operation = Data.define(:timestamp, :queries, :results, :duration)
end
