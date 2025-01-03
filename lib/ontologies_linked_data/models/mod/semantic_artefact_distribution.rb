module LinkedData
    module Models

        class SemanticArtefactDistribution
            
            # Artefact attrs that map with submission
            attr_accessor :id, :distributionId, :type, :accessURL, :description, :downloadURL, :license, :modified, :authorProperty,
                          :conformsToKnowledgeRepresentationParadigm, :definitionProperty, :hasSyntax,
                          :hierarchyProperty, :metadataVoc, :modifiedProperty, :obsoleteParent, :obsoleteProperty, 
                          :prefLabelProperty, :synonymProperty, :usedEngineeringMethodology
            
            # Attr special to SemanticArtefactDistribution
            attr_accessor :submission
            
            def initialize(submission)
                create_distribution(submission)
            end


            def self.goo_attrs_to_load(attributes = [], level = 0)
                # first extract submission attributes
                includes_attributes = if attributes.empty?
                                        default_attributes
                                    elsif attributes.first == :all
                                        all_attributes
                                    else
                                        attributes
                                    end
                submission_includes_attributes = change_distribution_to_submission_attrs(includes_attributes)
                includes = OntologySubmission.goo_attrs_to_load(submission_includes_attributes, level)

                # map again to artefacts attributes from ontology and submission attributes
                change_submission_to_distribution_attrs(includes)
            end

            def bring(*attributes)
                attributes = [attributes] unless attributes.is_a?(Array)
                submission_attributes_to_bring = self.class.change_distribution_to_submission_attrs(attributes)
                @submission.bring(*submission_attributes_to_bring)
                map_submission_to_distribution
            end

            private

            def create_distribution(submission)
                @submission = submission
                @submission.bring(*[:submissionId])
                @type = "http://www.isibang.ac.in/ns/mod#SemanticartefactDistribution"
                @id = submission.id
                @distributionId = submission.submissionId
            end
            
            def self.default_attributes
                [:id, :distributionId, :type, :accessURL, :description, :downloadURL, :license, :modified, :authorProperty]
            end
            
            def self.optional_attributes
                [
                    :conformsToKnowledgeRepresentationParadigm, :definitionProperty, :hasSyntax,
                    :hierarchyProperty, :metadataVoc, :modifiedProperty, :obsoleteParent, :obsoleteProperty,
                    :prefLabelProperty, :synonymProperty, :usedEngineeringMethodology
                ]
            end

            def self.all_attributes
                default_attributes + optional_attributes
            end
            
            def map_submission_to_distribution
                if @submission
                    @submission.instance_variables.each do |var|
                        submission_key = var.to_s.delete('@').to_sym
                        distribution_key = self.class.submission_distribution_mapping[submission_key]
                        next unless distribution_key
                        value = @submission.instance_variable_get(var)
                        send("#{distribution_key}=", value)
                    end
                end
            end

            def self.distribution_submission_mapping
                # id, distributionId and type are defined during initialization
                {
                    accessURL: :pullLocation,
                    description: :description,
                    downloadURL: :dataDump,
                    license: :hasLicense,
                    modified: :modificationDate,
                    authorProperty:	:authorProperty,
                    conformsToKnowledgeRepresentationParadigm: :conformsToKnowledgeRepresentationParadigm,
                    definitionProperty: :definitionProperty,
                    hasSyntax: :hasOntologySyntax,
                    hierarchyProperty: :hierarchyProperty,
                    metadataVoc: :metadataVoc,
                    modifiedProperty: :modifiedProperty,
                    obsoleteParent: :obsoleteParent,
                    obsoleteProperty: :obsoleteProperty,
                    prefLabelProperty: :prefLabelProperty,
                    synonymProperty: :synonymProperty,
                    usedEngineeringMethodology: :usedOntologyEngineeringMethodology,
                }
            end

            def self.change_distribution_to_submission_attrs(attributes)
                attributes.dup.map { |attr| distribution_submission_mapping[attr] }.compact
            end

            def self.submission_distribution_mapping
                distribution_submission_mapping.invert
            end

            def self.change_submission_to_distribution_attrs(attributes)
                attributes.dup.map { |attr| submission_distribution_mapping[attr] }.compact
            end


        end

    end
end
  