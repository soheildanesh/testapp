class ItemController < ApplicationController
    
    def index
        @showBaseLineTags = true
        @items = $items.find()
    end
    
    def showAlchemyTags
        @showBaseLineTags = false
        @items = $items.find()
        render 'index'
        #redirect_to action: 'index'
    end
end