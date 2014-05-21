{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE OverloadedStrings  #-}

module Main where

import           Control.Applicative ((<$>), (<*>))
import           Data.Binary         (Binary (..))
import           Data.Char           (isAlphaNum, isSpace, toLower, toUpper)
import           Data.Monoid         (mconcat, (<>))
import           Data.Typeable       (Typeable)
import           Hakyll
import           Prelude             hiding (id)
import           System.Cmd          (system)
import           System.Directory    (copyFile)
import           System.FilePath     (replaceExtension, takeDirectory)
import qualified Text.Pandoc         as Pandoc

main :: IO ()
main = hakyllWith config $ do
    -- Static files
    match ("images/*.jpg" .||. "images/*.png" .||. "images/*.gif" .||.
            "favicon.ico" .||. "files/**") $ do
        route   idRoute
        compile copyFileCompiler

    -- Formula images
    match "images/*.tex" $ do
        route   $ setExtension "png"
        compile $ getResourceBody
            >>= loadAndApplyTemplate "templates/formula.tex" defaultContext
            >>= pdflatex >>= pdfToPng

    -- Compress CSS
    match "css/*" $ do
        route idRoute
        compile compressCssCompiler

    -- Render the /tmp index page
    match "tmp/index.html" $ do
        route idRoute
        compile $ getResourceBody >>= relativizeUrls

    -- Build tags
    tags <- buildTags "posts/*" (fromCapture "tags/*.html")

    -- Render each and every post
    match "posts/*" $ do
        route   $ setExtension ".html"
        compile $ do
            pandocCompiler
                >>= saveSnapshot "content"
                >>= return . fmap demoteHeaders
                >>= loadAndApplyTemplate "templates/post.html" (postCtx tags)
                >>= loadAndApplyTemplate "templates/default.html" defaultContext
                >>= relativizeUrls

    -- Post list
    create ["posts.html"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let ctx = constField "title" "Posts" <>
                        listField "posts" (postCtx tags) (return posts) <>
                        defaultContext
            makeItem ""
                >>= loadAndApplyTemplate "templates/posts.html" ctx
                >>= loadAndApplyTemplate "templates/default.html" ctx
                >>= relativizeUrls

    -- Post tags
    tagsRules tags $ \tag pattern -> do
        let title = "Posts tagged " ++ tag

        -- Copied from posts, need to refactor
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll pattern
            let ctx = constField "title" title <>
                        listField "posts" (postCtx tags) (return posts) <>
                        defaultContext
            makeItem ""
                >>= loadAndApplyTemplate "templates/posts.html" ctx
                >>= loadAndApplyTemplate "templates/default.html" ctx
                >>= relativizeUrls

        -- Create RSS feed as well
        version "rss" $ do
            route   $ setExtension "xml"
            compile $ loadAllSnapshots pattern "content"
                >>= fmap (take 10) . recentFirst
                >>= renderRss (feedConfiguration title) feedCtx

    -- Index
    match "index.html" $ do
        route idRoute
        compile $ do
            posts <- fmap (take 3) . recentFirst =<< loadAll "posts/*"
            let indexContext =
                    listField "posts" (postCtx tags) (return posts) <>
                    field "tags" (\_ -> renderTagList tags) <>
                    defaultContext

            getResourceBody
                >>= applyAsTemplate indexContext
                >>= loadAndApplyTemplate "templates/default.html" indexContext
                >>= relativizeUrls

    -- Read templates
    match "templates/*" $ compile $ templateCompiler

    -- Render some static pages
    let pages =
            [ "README.md"
            , "links.markdown"
            , "recommendations.markdown"
            ]
    match (fromList pages) $ do
        route   $ setExtension ".html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" defaultContext
            >>= relativizeUrls

    -- Render the 404 page, we don't relativize URL's here.
    match "404.html" $ do
        route idRoute
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" defaultContext

    -- Render RSS feed
    create ["rss.xml"] $ do
        route idRoute
        compile $ do
            loadAllSnapshots "posts/*" "content"
                >>= fmap (take 10) . recentFirst
                >>= renderRss (feedConfiguration "All posts") feedCtx

postCtx :: Tags -> Context String
postCtx tags = mconcat
    [ modificationTimeField "mtime" "%U"
    , dateField "date" "%B %e, %Y"
    , tagsField "tags" tags
    , defaultContext
    ]

feedCtx :: Context String
feedCtx = mconcat
    [ bodyField "description"
    , defaultContext
    ]

config :: Configuration
config = defaultConfiguration
    { deployCommand = "rsync --checksum -ave 'ssh -p 2222' \
                      \_site/* jaspervdj@jaspervdj.be:jaspervdj.be"
    }

feedConfiguration :: String -> FeedConfiguration
feedConfiguration title = FeedConfiguration
    { feedTitle       = "jaspervdj - " ++ title
    , feedDescription = "Personal blog of jaspervdj"
    , feedAuthorName  = "Jasper Van der Jeugt"
    , feedAuthorEmail = "jaspervdj@gmail.com"
    , feedRoot        = "http://jaspervdj.be"
    }

pdflatex :: Item String -> Compiler (Item TmpFile)
pdflatex item = do
    TmpFile texPath <- newTmpFile "pdflatex.tex"
    let tmpDir  = takeDirectory texPath
        pdfPath = replaceExtension texPath "pdf"

    unsafeCompiler $ do
        writeFile texPath $ itemBody item
        _ <- system $ unwords ["pdflatex", "-halt-on-error",
            "-output-directory", tmpDir, texPath, ">/dev/null", "2>&1"]
        return ()

    makeItem $ TmpFile pdfPath

pdfToPng :: Item TmpFile -> Compiler (Item TmpFile)
pdfToPng item = do
    let TmpFile pdfPath = itemBody item
        pngPath         = replaceExtension pdfPath "png"
    unsafeCompiler $ do
        _ <- system $ unwords ["convert", "-density", "150", "-quality", "90",
                pdfPath, pngPath]
        return ()
    makeItem $ TmpFile pngPath

capitalize :: String -> String
capitalize []       = []
capitalize (x : xs) = toUpper x : xs

galleryCtx :: Tags -> Context a
galleryCtx tags = listField "galleries" itemCtx $
    return [Item (tagsMakeId tags name) name | (name, _) <- tagsMap tags]
  where
    itemCtx = mconcat
        [ field "title" $ return . itemBody
        , field "size"  $ \item -> return $
            show $ maybe 0 length $ lookup (itemBody item) (tagsMap tags)
        , defaultContext
        ]

urlFriendlyTag :: String -> String
urlFriendlyTag []  = []
urlFriendlyTag (c : cs)
    | isSpace c    = '-'       : urlFriendlyTag cs
    | isAlphaNum c = toLower c : urlFriendlyTag cs
    | otherwise    =             urlFriendlyTag cs
