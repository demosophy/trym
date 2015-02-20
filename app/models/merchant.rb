class Merchant < ActiveRecord::Base
	has_many :charges
	has_many :notes, as: :noteable
	fuzzily_searchable :name

	scope :validated, -> {where(validated: true)}

	def self.find_by_fuzzy_name_with_similar_threshold(query, threshold = 70)
		result = validated.find_by_fuzzy_name(query, limit: 1).first rescue nil
		if result.present? && (result.name.similar(query) >= threshold || query.downcase.include?(result.name.downcase))
			result
		else
			nil
		end
	end

	def self.selection_search(query)
		find_by_fuzzy_name(query, limit: 5).select(&:validated) + [OpenStruct.new(id: query, name: "New: " + query)]
	end

end