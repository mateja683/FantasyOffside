require 'database_cleaner'

DatabaseCleaner.strategy = :truncation

describe 'API' do

  let(:browser) { double(:browser, goto: true, close: true) }
  let(:row) { double(:row) }

  before :each do
    DatabaseCleaner.clean
  end

  describe 'squad scraping' do
    it 'scrapes the user\'s squad and returns details', type: :request do
      Player.create(playerdata: "test_player", teamid: 1, position: "Goalkeeper", price: 5.5)
      Team.create(name: "test_team")

      allow(Watir::Browser).to receive(:new).and_return(browser)
      allow(browser).to receive_message_chain("table.rows") { ["", row] }
      allow(row).to receive_message_chain(:cells, :[], :link, :href) { "1" }

      get getsquad_path(fplid: '0000000')
      expect(response.status).to eq(200)
      expect(response.content_type).to eq(Mime::JSON)
      expect(response.body).to eq "[[\"test_player\",\"test_team\",\"Goalkeeper\",5.5]]"
    end

    it 'should throw an error if fplid is not a number', type: :request do
      get getsquad_path(fplid: 'abcdef')
      expect(response.status).to eq(400)
      expect(response.content_type).to eq(Mime::JSON)
      expect(response.body).to eq "Invalid team id number"
    end

    it 'should throw an error if a blank fplid is provided', type: :request do
      get getsquad_path(fplid: '')
      expect(response.status).to eq(400)
      expect(response.content_type).to eq(Mime::JSON)
      expect(response.body).to eq "Invalid team id number"
    end

    it 'should throw an error if no parameter is provided', type: :request do
      get getsquad_path()
      expect(response.status).to eq(400)
      expect(response.content_type).to eq(Mime::JSON)
      expect(response.body).to eq "Invalid team id number"
    end
  end

  describe 'getting transfers' do
    it 'should suggest transfer which excludes current squad', type: :request do
      (1..5).each do |i|
        3.times do
          Player.create(playerdata: "player", teamid: i, position: "Goalkeeper", price: 1)
        end
      end
      Player.create(playerdata: "player16", teamid: 1, position: "Goalkeeper", price: 1)
      squad = "[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]"
      allow_any_instance_of(Array).to receive(:sample).and_return(1)
      get transfers_path(squad: squad, cash: 10)
      expect(response.status).to eq(200)
      expect(response.content_type).to eq(Mime::JSON)
      expect(response.body).to eq('{"out":"player","in":"player16"}')
    end

    it 'should suggest a transfer of correct position', type: :request do
      (1..5).each do |i|
        3.times do
          Player.create(playerdata: "player", teamid: i, position: "Goalkeeper", price: 1)
        end
      end
      Player.create(playerdata: "player16", teamid: 1, position: "Goalkeeper", price: 1)
      Player.create(playerdata: "player17", teamid: 1, position: "Defender", price: 1)
      squad = "[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]"
      allow_any_instance_of(Array).to receive(:sample).and_return(1)
      get transfers_path(squad: squad, cash: 10)
      expect(response.status).to eq(200)
      expect(response.content_type).to eq(Mime::JSON)
      expect(response.body).to eq('{"out":"player","in":"player16"}')
    end

    it 'should suggest transfer that doesn\'t exceed cash constraint', type: :request do
      (1..5).each do |i|
        3.times do
          Player.create(playerdata: "player", teamid: i, position: "Goalkeeper", price: 1)
        end
      end
      Player.create(playerdata: "player16", teamid: 1, position: "Goalkeeper", price: 11)
      Player.create(playerdata: "player17", teamid: 1, position: "Goalkeeper", price: 12)
      squad = "[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]"
      allow_any_instance_of(Array).to receive(:sample).and_return(1)
      get transfers_path(squad: squad, cash: 10)
      expect(response.status).to eq(200)
      expect(response.content_type).to eq(Mime::JSON)
      expect(response.body).to eq('{"out":"player","in":"player16"}')
    end

    it 'should suggest a transfer that doesn\'t exceed max players per team', type: :request do
      (1..5).each do |i|
        3.times do
          Player.create(playerdata: "player", teamid: i, position: "Goalkeeper", price: 1)
        end
      end
      Player.create(playerdata: "player16", teamid: 2, position: "Goalkeeper", price: 1)
      Player.create(playerdata: "player17", teamid: 6, position: "Goalkeeper", price: 1)
      squad = "[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]"
      allow_any_instance_of(Array).to receive(:sample).and_return(1)
      get transfers_path(squad: squad, cash: 10)
      expect(response.status).to eq(200)
      expect(response.content_type).to eq(Mime::JSON)
      expect(response.body).to eq('{"out":"player","in":"player17"}')
    end


    describe 'parameter validation' do
      it 'should throw an error if no parameter is provided', type: :request do
        get transfers_path(cash: 10)
        expect(response.status).to eq(400)
        expect(response.content_type).to eq(Mime::JSON)
        expect(response.body).to eq "Invalid parameters"
      end

      it 'should throw an error if squad is blank', type: :request do
        get transfers_path(squad: '', cash: 10)
        expect(response.status).to eq(400)
        expect(response.content_type).to eq(Mime::JSON)
        expect(response.body).to eq "Invalid parameters"
      end

      it 'should throw an error if squad is not the correct size', type: :request do
        squad = "[1,2,3,4,5,6,7,8,9,10,11,12,13,14]"
        get transfers_path(squad: squad, cash: 10)
        expect(response.status).to eq(400)
        expect(response.content_type).to eq(Mime::JSON)
        expect(response.body).to eq "Invalid parameters"
      end

      it 'should throw an error if £ in the bank is not provided', type: :request do
        squad = "[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]"
        get transfers_path(squad: squad)
        expect(response.status).to eq(400)
        expect(response.content_type).to eq(Mime::JSON)
        expect(response.body).to eq("Invalid parameters")
      end

      it 'should throw an error if £ in the bank is blank', type: :request do
        squad = "[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]"
        get transfers_path(squad: squad, cash: '')
        expect(response.status).to eq(400)
        expect(response.content_type).to eq(Mime::JSON)
        expect(response.body).to eq("Invalid parameters")
      end

      it 'should throw an error if £ in the bank is non-numeric', type: :request do
        squad = "[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]"
        get transfers_path(squad: squad, cash: '123abc')
        expect(response.status).to eq(400)
        expect(response.content_type).to eq(Mime::JSON)
        expect(response.body).to eq("Invalid parameters")
      end
    end
  end
end
