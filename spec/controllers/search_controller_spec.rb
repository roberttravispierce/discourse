require 'rails_helper'

describe SearchController do

  context "integration" do
    before do
      SearchIndexer.enable
    end

    it "can search correctly" do
      my_post = Fabricate(:post, raw: 'this is my really awesome post')
      xhr :get, :query, term: 'awesome', include_blurb: true

      expect(response).to be_success
      data = JSON.parse(response.body)
      expect(data['posts'][0]['id']).to eq(my_post.id)
      expect(data['posts'][0]['blurb']).to eq('this is my really awesome post')
      expect(data['topics'][0]['id']).to eq(my_post.topic_id)
    end

    it 'performs the query with a type filter' do
      user = Fabricate(:user)
      my_post = Fabricate(:post, raw: "#{user.username} is a cool person")
      xhr :get, :query, term: user.username, type_filter: 'topic'

      expect(response).to be_success
      data = JSON.parse(response.body)

      expect(data['posts'][0]['id']).to eq(my_post.id)
      expect(data['users']).to be_blank

      xhr :get, :query, term: user.username, type_filter: 'user'
      expect(response).to be_success
      data = JSON.parse(response.body)

      expect(data['posts']).to be_blank
      expect(data['users'][0]['id']).to eq(user.id)
    end

    it "can search for id" do
      user = Fabricate(:user)
      my_post = Fabricate(:post, raw: "#{user.username} is a cool person")
      xhr(
        :get,
        :query,
        term: my_post.topic_id,
        type_filter: 'topic',
        search_for_id: true
      )
      expect(response).to be_success
      data = JSON.parse(response.body)
      expect(data['topics'][0]['id']).to eq(my_post.topic_id)
    end
  end

  context "#query" do
    it "logs the search term" do
      SiteSetting.log_search_queries = true
      xhr :get, :query, term: 'wookie'
      expect(response).to be_success
      expect(SearchLog.where(term: 'wookie')).to be_present
    end

    it "doesn't log when disabled" do
      SiteSetting.log_search_queries = false
      xhr :get, :query, term: 'wookie'
      expect(response).to be_success
      expect(SearchLog.where(term: 'wookie')).to be_blank
    end
  end

  context "#show" do
    it "logs the search term" do
      SiteSetting.log_search_queries = true
      xhr :get, :show, q: 'bantha'
      expect(response).to be_success
      expect(SearchLog.where(term: 'bantha')).to be_present
    end

    it "doesn't log when disabled" do
      SiteSetting.log_search_queries = false
      xhr :get, :show, q: 'bantha'
      expect(response).to be_success
      expect(SearchLog.where(term: 'bantha')).to be_blank
    end
  end

  context "search context" do
    it "raises an error with an invalid context type" do
      expect {
        xhr :get, :query, term: 'test', search_context: {type: 'security', id: 'hole'}
      }.to raise_error(Discourse::InvalidParameters)
    end

    it "raises an error with a missing id" do
      expect {
        xhr :get, :query, term: 'test', search_context: {type: 'user'}
      }.to raise_error(Discourse::InvalidParameters)
    end

    context "with a user" do
      let(:user) { Fabricate(:user) }
      it "raises an error if the user can't see the context" do
        Guardian.any_instance.expects(:can_see?).with(user).returns(false)
        xhr :get, :query, term: 'test', search_context: {type: 'user', id: user.username}
        expect(response).not_to be_success
      end

      it 'performs the query with a search context' do
        xhr :get, :query, term: 'test', search_context: {type: 'user', id: user.username}
        expect(response).to be_success
      end
    end

  end

end
