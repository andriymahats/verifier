require 'nokogiri'

module CertPub

  module Spec

    class PublisherV1Signing

      def self.perform(address, participant)
        instance = self::new address, participant
        instance.listing_current
      end

      def initialize(address, participant)
        @client = CertPub::Util::RestClient address
        @participant = participant
      end

      def listing_current
        path = "api/v1/sig/#{@participant.escaped}"

        puts "Address: #{@client.base_url}"
        puts "Path: #{path}"

        resp = @client.get(path)

        if resp.status == 200
          puts "Status: #{Rainbow(resp.status).green}"

          xml = Nokogiri::XML(resp.body)
          puts "Process references: #{Rainbow(xml.css("Participant ProcessReference").count).cyan}"
          puts

          xml.css("Participant ProcessReference").sort_by(&:text).each do |e|
            process = CertPub::Model::Process::new e.text, e.xpath('@qualifier')
            role = e.xpath('@role')
            
            single_current process, role
            puts
          end
        else
          puts "Status: #{Rainbow(resp.status).red}"
          puts "Response: #{Rainbow(resp.body).red}"
        end
      end

      def single_current(process, role)
        puts Rainbow("  Process: #{process.scheme}::").blue + Rainbow(process.value).blue.bright + Rainbow(" @ #{role}").blue
        path = "api/v1/sig/#{@participant.escaped}/#{process.escaped}/#{role}"

        puts "  Address: #{@client.base_url}"
        puts "  Path: #{path}"

        resp = @client.get(path)
        
        if resp.status == 200
          puts "  Status: #{Rainbow(resp.status).green}"
        
          xml = Nokogiri::XML(resp.body)

          xml_participant = xml.css('Process ParticipantIdentifier')
          res_participant = CertPub::Model::Participant::new xml_participant.text(), xml_participant.xpath('@qualifier')
          puts "  Participant: #{Rainbow(res_participant).color(@participant == res_participant ? :green : :red)}"

          xml_process = xml.css('Process ProcessIdentifier')
          res_process = CertPub::Model::Process::new xml_process.text, xml_process.xpath('@qualifier')
          puts "  Process: #{Rainbow(res_process).color(process == res_process ? :green : :red)}"

          # TODO: Date
          # TODO: Role

          puts "  Certificate:"
          xml.css('Certificate').each do |cert|
            certificate = OpenSSL::X509::Certificate.new Base64.decode64(cert.css('Binary').text)

            puts "  - Subject: #{Rainbow(certificate.subject).cyan}"
            puts "    Issuer: #{Rainbow(certificate.issuer).cyan}"
            puts "    Serialnumber: #{Rainbow(certificate.serial).color(cert.xpath('@serialNumber').to_s == certificate.serial.to_s ? :green : :red)}"
            puts "    Expire: #{Rainbow(certificate.not_after).cyan}"
          end
        else
          puts "  Status: #{Rainbow(resp.status).red.bright}"
          puts "  Response: #{Rainbow(resp.body).red}"
        end
      end

    end

  end

end