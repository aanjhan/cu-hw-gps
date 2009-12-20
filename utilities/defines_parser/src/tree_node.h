#ifndef TREE_NODE_H
#define TREE_NODE_H

#include <string>

class TreeNode
{
public:
    TreeNode(int type, const std::string &value) : type(type), value(value), left(NULL), right(NULL) {}
    TreeNode(int type, TreeNode *left, TreeNode *right) : type(type), value(""), left(left), right(right) {}
    ~TreeNode();

    int GetType(){ return type; }
    std::string GetValue(){ return value; }
    TreeNode* GetLeft(){ return left; }
    TreeNode* GetRight(){ return right; }

    void SetValue(const std::string &value){ this->value=value; }
    void SetLeft(TreeNode *left){ this->left=left; }
    void SetRight(TreeNode *right){ this->right=right; }
    
private:
    int type;
    std::string value;
    TreeNode *left, *right;
};

#endif
